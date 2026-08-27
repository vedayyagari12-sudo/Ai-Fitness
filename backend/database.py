import logging
import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

load_dotenv()

logger = logging.getLogger("physiqo")

# Stripped, and blank treated as absent: an environment variable set to an
# empty string is an ordinary way to misconfigure a Cloud Run service, and
# "not set" is a truer diagnosis for it than "not parseable".
SQLALCHEMY_DATABASE_URL = (os.getenv("DATABASE_URL") or "").strip() or None

# Why this is not just `create_engine(os.getenv("DATABASE_URL"))`:
#
# That raises during import, before FastAPI is constructed, so the process
# never binds a port. On Cloud Run a container that never listens is reported
# as a startup probe timeout — a message about the port, with no mention of
# the database. The one failure the health endpoints exist to distinguish
# (app up, database not) becomes the one failure they cannot report, because
# nothing is running to answer them.
#
# So a missing or malformed URL is recorded instead of raised. The app starts,
# "/" answers 200, and every route that needs the database answers 503 saying
# exactly what is wrong. A *wrong* URL that is still well-formed — bad host,
# bad password — cannot be caught here at all: SQLAlchemy connects lazily, so
# that surfaces on the first query, which is what /test-db is for.
engine = None
engine_error: str | None = None

if not SQLALCHEMY_DATABASE_URL:
    engine_error = "DATABASE_URL is not set"
else:
    try:
        # Pooling and connect_timeout are Postgres/psycopg2 concepts. SQLite
        # rejects connect_timeout outright with a TypeError and ignores the
        # pool sizes, so a non-Postgres URL — which tests and local scripts
        # legitimately use — gets a plain engine.
        pg_options = {}
        if SQLALCHEMY_DATABASE_URL.startswith(("postgresql", "postgres")):
            pg_options = dict(
                # Cloud Run bills per request and throttles CPU to near zero
                # between them, so an idle instance's pooled connections go
                # stale without the app ever noticing. Postgres (and the
                # Supabase pooler in front of it) then drops them, and the
                # next request checks out a dead socket and fails or hangs on
                # its first query. pool_pre_ping spends one cheap round trip
                # validating a connection before handing it over, turning
                # that failure into a transparent reconnect.
                pool_pre_ping=True,
                # Discard anything older than five minutes rather than
                # waiting to find out it is dead — comfortably under the
                # pooler's own idle timeout, so we retire connections first.
                pool_recycle=300,
                # Deliberately small. Cloud Run scales by adding INSTANCES,
                # and each keeps its own pool, so the count against Postgres
                # is pool_size x instances. A default 5 (+10 overflow) across
                # twenty instances would exhaust the connection limit; a
                # couple per instance will not, and one instance serves few
                # enough concurrent requests to need more.
                pool_size=2,
                max_overflow=3,
                # Fail loudly rather than hanging a request forever when the
                # pool is exhausted.
                pool_timeout=10,
                connect_args={"connect_timeout": 10},
            )

        engine = create_engine(SQLALCHEMY_DATABASE_URL, **pg_options)
    except Exception as exc:
        # Deliberately the exception's class and not its message: SQLAlchemy
        # quotes the offending URL back in ArgumentError, and that URL carries
        # the database password. Logging it would put the credential into
        # Cloud Logging in plain text, where it long outlives the container.
        engine_error = (
            "DATABASE_URL is set but is not a usable connection string "
            f"({exc.__class__.__name__}) - check the scheme and that the "
            "password is percent-encoded"
        )

if engine_error:
    logger.error(
        "startup: %s. The app will serve, but every database route will "
        "return 503 until this is fixed.",
        engine_error,
    )

# None when there is no engine. get_db() checks for that and turns it into a
# 503 naming the cause; binding a sessionmaker to None instead would defer the
# failure to an opaque UnboundExecutionError on first query.
SessionLocal = (
    sessionmaker(autocommit=False, autoflush=False, bind=engine)
    if engine is not None
    else None
)

Base = declarative_base()
