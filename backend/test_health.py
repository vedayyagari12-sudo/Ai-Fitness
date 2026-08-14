"""Health endpoint contract.

Uptime monitors are the only consumer of these two routes, and both ways
they can lie are silent: answering HEAD with 405 makes a healthy service
look down, and reporting "Database connected!" without querying makes a
dead database look healthy. Neither shows up in normal use, so they are
pinned here.

Run with:  python -m pytest backend/test_health.py
"""

import pytest
from fastapi import Depends, FastAPI, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker


def build_app(database_url: str) -> FastAPI:
    """Mirrors the health routes in main.py against a chosen database.

    Rebuilt here rather than importing main, which needs the full runtime
    environment (Supabase keys, a Gemini key) that a routing test should not
    require.
    """
    engine = create_engine(database_url)
    session_factory = sessionmaker(bind=engine)

    def get_db():
        db = session_factory()
        try:
            yield db
        finally:
            db.close()

    app = FastAPI()

    def liveness() -> dict:
        return {"status": "ok", "message": "Physiqo AI backend is running"}

    def readiness(db: Session) -> dict:
        try:
            db.execute(text("SELECT 1"))
        except Exception:
            raise HTTPException(status_code=503, detail="Database unreachable")
        return {"status": "ok", "message": "Database connected!"}

    app.get("/")(lambda: liveness())
    app.head("/")(lambda: liveness())
    app.get("/test-db")(lambda db=Depends(get_db): readiness(db))
    app.head("/test-db")(lambda db=Depends(get_db): readiness(db))
    return app


WORKING_DB = "sqlite://"
# Nothing listens here, so any real query fails.
DEAD_DB = "postgresql://u:p@127.0.0.1:5433/nope"


@pytest.fixture
def healthy():
    return TestClient(build_app(WORKING_DB), raise_server_exceptions=False)


@pytest.fixture
def db_down():
    return TestClient(build_app(DEAD_DB), raise_server_exceptions=False)


@pytest.mark.parametrize("path", ["/", "/test-db"])
def test_head_is_supported(healthy, path):
    """FastAPI's APIRoute does not add HEAD to a GET route the way
    Starlette's plain Route does, so a bare @app.get answers 405 — and
    uptime monitors send HEAD by default."""
    assert healthy.head(path).status_code == 200


@pytest.mark.parametrize("path", ["/", "/test-db"])
def test_get_is_supported(healthy, path):
    assert healthy.get(path).status_code == 200


def test_readiness_fails_when_the_database_is_unreachable(db_down):
    """The regression that mattered: the endpoint reported success without
    ever querying, because a SQLAlchemy Session is lazy and the handler
    never used it."""
    assert db_down.get("/test-db").status_code == 503
    assert db_down.head("/test-db").status_code == 503


def test_liveness_stays_up_when_the_database_is_down(db_down):
    """Separate endpoints on purpose: the process being alive and the
    database being reachable are different questions."""
    assert db_down.get("/").status_code == 200


def test_both_endpoints_share_a_response_shape(healthy):
    """A monitor asserting on "status": "ok" should work against either."""
    for path in ("/", "/test-db"):
        assert set(healthy.get(path).json()) == {"status", "message"}


def test_head_returns_no_body(healthy):
    assert healthy.head("/").content == b""


def test_operation_ids_are_unique(healthy):
    """One api_route carrying GET and HEAD emits two OpenAPI operations
    sharing a single operationId, which is spec-invalid — and the id is
    derived from an unordered set, so it changes between restarts."""
    spec = healthy.app.openapi()
    ids = [op["operationId"] for p in spec["paths"].values() for op in p.values()]
    assert len(ids) == len(set(ids)), ids
