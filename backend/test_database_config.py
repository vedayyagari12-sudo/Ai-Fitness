"""What happens when DATABASE_URL is wrong.

This is a deployment contract, not a unit test. Building the engine at import
means a bad connection string kills the process before FastAPI exists, so the
container never binds a port and Cloud Run reports a startup probe timeout —
a message about a port, with nothing about the database. The one failure the
health endpoints exist to describe becomes the one they cannot reach.

Run with:  python -m pytest backend/test_database_config.py
"""

import importlib
import sys

import pytest

MODULE = "backend.database"

# A password that must never appear in a log line or an error string.
SECRET = "sup3rs3cr3t-pw"


def load(monkeypatch, url):
    """Import backend.database fresh with DATABASE_URL set to [url]."""
    for name in [m for m in sys.modules if m.startswith("backend")]:
        del sys.modules[name]
    if url is None:
        monkeypatch.delenv("DATABASE_URL", raising=False)
        # database.py calls load_dotenv(), which would otherwise refill the
        # variable from a developer's local backend/.env and make the
        # "unset" case untestable.
        monkeypatch.setattr("dotenv.load_dotenv", lambda *a, **k: False)
    else:
        monkeypatch.setenv("DATABASE_URL", url)
    return importlib.import_module(MODULE)


def test_missing_url_does_not_crash_the_import(monkeypatch):
    """The whole point: the process must survive to answer for itself."""
    db = load(monkeypatch, None)
    assert db.engine is None
    assert db.SessionLocal is None
    assert "not set" in db.engine_error


def test_malformed_url_does_not_crash_the_import(monkeypatch):
    db = load(monkeypatch, f"postgres-typo://user:{SECRET}@host:5432/db")
    assert db.engine is None
    assert db.SessionLocal is None
    assert "not a usable connection string" in db.engine_error


def test_the_error_never_quotes_the_password(monkeypatch):
    """SQLAlchemy puts the offending URL — password included — into its
    ArgumentError message. Logging that verbatim would write the credential
    into Cloud Logging in plain text, where it outlives the container by far
    longer than the deploy it was meant to help debug."""
    db = load(monkeypatch, f"postgres-typo://user:{SECRET}@host:5432/db")
    assert SECRET not in db.engine_error
    assert "user" not in db.engine_error


def test_the_error_says_what_to_do(monkeypatch):
    db = load(monkeypatch, f"postgres-typo://user:{SECRET}@host/db")
    assert "scheme" in db.engine_error
    assert "percent-encoded" in db.engine_error


def test_a_well_formed_url_still_builds_an_engine(monkeypatch):
    db = load(monkeypatch, "sqlite://")
    assert db.engine is not None
    assert db.SessionLocal is not None
    assert db.engine_error is None


def test_an_unreachable_host_is_not_caught_here(monkeypatch):
    """SQLAlchemy connects lazily, so a well-formed URL pointing at nothing
    builds an engine successfully. That failure belongs to /test-db, which
    round-trips a real query; catching it here is not possible and pretending
    otherwise would give a false sense of coverage."""
    db = load(monkeypatch, "postgresql://u:p@127.0.0.1:5433/nope")
    assert db.engine is not None
    assert db.engine_error is None


@pytest.mark.parametrize(
    "url",
    [
        "",  # set but empty, e.g. a blank Cloud Run env var
        "   ",  # whitespace only
    ],
)
def test_blank_values_are_treated_as_unset(monkeypatch, url):
    """An empty environment variable is a normal way to misconfigure a Cloud
    Run service, and it must not reach create_engine."""
    db = load(monkeypatch, url)
    assert db.SessionLocal is None
    assert "not set" in db.engine_error
