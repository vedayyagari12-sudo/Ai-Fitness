"""Serverless performance configuration.

None of this is visible in normal use — a stale-connection stall, a
handshake paid twice, four round trips where one would do. It shows up only
as "the app feels slow", which is exactly the kind of thing that regresses
silently. So the shape of the configuration is pinned here.

Run with:  python -m pytest backend/test_perf_config.py
"""

import asyncio
import importlib
import sys
import time

import pytest


def load_database(monkeypatch, url):
    for name in [m for m in sys.modules if m.startswith("backend")]:
        del sys.modules[name]
    monkeypatch.setenv("DATABASE_URL", url)
    return importlib.import_module("backend.database")


PG_URL = "postgresql://u:p@127.0.0.1:5433/nope"


class TestEnginePooling:
    """Cloud Run throttles CPU to near zero between requests, so pooled
    connections go stale while an instance is idle and the next request
    checks out a dead socket."""

    def test_pre_ping_is_on(self, monkeypatch):
        db = load_database(monkeypatch, PG_URL)
        assert db.engine.pool._pre_ping is True, (
            "without pre-ping the first request after an idle period fails or "
            "hangs on a connection the pool still believes is good"
        )

    def test_connections_are_recycled_well_before_an_idle_timeout(
        self, monkeypatch
    ):
        db = load_database(monkeypatch, PG_URL)
        recycle = db.engine.pool._recycle
        assert 0 < recycle <= 600, (
            f"pool_recycle is {recycle}; it must be short enough to retire a "
            "connection before the pooler drops it, and not -1 (never)"
        )

    def test_the_pool_is_small_enough_for_many_instances(self, monkeypatch):
        # Cloud Run scales by adding instances, each with its own pool, so
        # the total against Postgres is pool_size x instances.
        db = load_database(monkeypatch, PG_URL)
        size = db.engine.pool.size()
        overflow = db.engine.pool._max_overflow
        assert size + overflow <= 8, (
            f"pool_size {size} + max_overflow {overflow} per instance will "
            "exhaust Postgres once Cloud Run scales out"
        )

    def test_a_request_cannot_wait_on_the_pool_forever(self, monkeypatch):
        db = load_database(monkeypatch, PG_URL)
        assert 0 < db.engine.pool._timeout <= 30

    def test_a_non_postgres_url_still_builds(self, monkeypatch):
        # connect_timeout is psycopg2-only; SQLite raises TypeError on it.
        # Tests and local scripts legitimately use sqlite, so the Postgres
        # options have to be conditional rather than unconditional.
        db = load_database(monkeypatch, "sqlite://")
        assert db.engine is not None
        assert db.engine_error is None


class TestSharedHttpClient:
    """Every Supabase read used to open its own AsyncClient, pay a full TLS
    handshake, and then discard the warmed connection."""

    def test_one_client_is_reused_across_calls(self):
        import backend.main as m

        async def scenario():
            async with m.lifespan(m.app):
                first = m.http_client()
                second = m.http_client()
                assert first is second, (
                    "a new client per call means a new TLS handshake per call"
                )
                assert not first.is_closed
                return first

        client = asyncio.run(scenario())
        # The lifespan owns the client and must close it on shutdown, or a
        # container that keeps restarting leaks sockets.
        assert client.is_closed

    def test_the_client_keeps_connections_alive(self):
        import backend.main as m

        async def scenario():
            async with m.lifespan(m.app):
                pool = m.http_client()._transport._pool
                assert pool._max_keepalive_connections >= 5, (
                    "too few keepalive slots and connections get dropped "
                    "between calls, which is the cost being avoided"
                )
                assert pool._keepalive_expiry >= 30

        asyncio.run(scenario())

    def test_requests_are_bounded_by_a_timeout(self):
        import backend.main as m

        # httpx defaults to no timeout at all. On Cloud Run a hung upstream
        # would then hold the request open until the platform's own timeout,
        # billing CPU for the whole wait.
        assert m.REQUEST_TIMEOUT.read is not None
        assert m.REQUEST_TIMEOUT.connect is not None

    def test_there_is_a_fallback_when_the_app_never_started(self):
        # Importing a handler without running the lifespan must not crash;
        # it just gets an unpooled client.
        import backend.main as m

        assert m._http is None
        c = m.http_client()
        assert c is not None
        asyncio.run(c.aclose())


class TestConcurrentReads:
    """The dashboard's five reads are independent — none needs another's
    result — so they should overlap rather than queue."""

    def test_gather_overlaps_work_that_sleep_would_serialise(self):
        # A behavioural check on the pattern the endpoint now uses: five
        # 50ms waits take ~50ms concurrently and ~250ms sequentially, so the
        # elapsed time distinguishes them unambiguously.
        async def one():
            await asyncio.sleep(0.05)
            return 1

        async def concurrently():
            start = time.perf_counter()
            await asyncio.gather(*(one() for _ in range(5)))
            return time.perf_counter() - start

        elapsed = asyncio.run(concurrently())
        assert elapsed < 0.15, (
            f"five concurrent 50ms reads took {elapsed:.3f}s — that is "
            "sequential, not concurrent"
        )

    def test_the_dashboard_gathers_its_reads(self):
        # Guards the endpoint itself rather than the pattern: the previous
        # version awaited each read on its own line.
        import inspect
        import backend.main as m

        src = inspect.getsource(m.get_dashboard)
        assert "asyncio.gather" in src, (
            "the dashboard is awaiting its reads one at a time again"
        )
        assert "asyncio.to_thread" in src, (
            "the blocking workout query must go to a thread, both so it can "
            "overlap the HTTP reads and so it does not stall the event loop"
        )

    def test_the_blocking_query_does_not_sit_on_the_event_loop(self):
        # A blocking socket read inside an `async def` handler stalls every
        # other request the instance is serving, not just this one.
        import inspect
        import backend.main as m

        src = inspect.getsource(m.get_dashboard)
        gather_at = src.index("asyncio.gather")
        # No bare `db.query(` should remain outside the threaded helper.
        after = src[gather_at:]
        assert "db.query(" not in after, (
            "a synchronous db.query runs after the gather, back on the loop"
        )


@pytest.mark.parametrize(
    "table,columns",
    [
        ("calorie_logs", ("user_id", "created_at")),
        ("bodyweight_logs", ("user_id", "created_at")),
        ("physique_scans", ("user_id", "created_at")),
        ("workouts", ("user_id", "created_at")),
    ],
)
def test_an_index_is_shipped_for_every_hot_read_path(table, columns):
    """Each of these tables is filtered by user_id and by a created_at
    window. A single-column index on user_id cannot serve that: Postgres
    finds the user's rows, then reads and date-filters all of them, so the
    work scales with total history rather than the window asked for."""
    import pathlib

    sql = (
        pathlib.Path(__file__).parent / "supabase_indexes.sql"
    ).read_text(encoding="utf-8").lower()
    assert table in sql, f"no index shipped for {table}"
    # Column order matters — the equality column has to lead.
    assert f"{columns[0]}, {columns[1]}" in sql, (
        f"{table}'s index must lead with {columns[0]}"
    )


def test_the_workout_model_declares_the_same_index():
    """The model and the SQL have to agree, or a fresh database and an
    existing one end up with different schemas."""
    from backend.models import Workout

    names = {ix.name for ix in Workout.__table__.indexes}
    assert any("user_id" in n and "created_at" in n for n in names), names
