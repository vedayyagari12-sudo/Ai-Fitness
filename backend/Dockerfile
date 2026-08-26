# syntax=docker/dockerfile:1

# Build context is this directory (backend/), so:
#   gcloud run deploy physiqo-api --source backend/
#   docker build -t physiqo-api backend/

# ── builder ─────────────────────────────────────────────────────────────────
# Compilers live here and nowhere else. Anything needing a C toolchain gets
# built into the venv now, and only the finished venv crosses into the runtime
# image, so the shipped container carries no build-essential and no headers.
FROM python:3.13-slim AS builder

# libffi-dev is for cryptography, which PyJWT[crypto] pulls in for the RS256
# JWKS verification. build-essential covers anything without a cp313 wheel.
RUN apt-get update && apt-get install --no-install-recommends -y \
        build-essential \
        libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# A venv rather than --user: one self-contained directory to copy across,
# with no site-packages layout to keep in sync between the two stages.
ENV VIRTUAL_ENV=/opt/venv
RUN python -m venv "$VIRTUAL_ENV"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Upgraded before installing anything: an old pip picks source distributions
# where a manylinux wheel exists, which is how a slim image ends up compiling
# psycopg2 and failing on a missing libpq.
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Copied on its own so this layer is cached against requirements.txt alone.
# Application edits then rebuild in seconds instead of reinstalling the world.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── runtime ─────────────────────────────────────────────────────────────────
FROM python:3.13-slim AS runtime

# PYTHONDONTWRITEBYTECODE: the filesystem is read-only apart from /tmp, and
#   .pyc files next to the source would be written on every import.
# PYTHONUNBUFFERED: without it Cloud Run Logging shows nothing until a buffer
#   fills, so a crash loop looks like a silent container.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH=/app

COPY --from=builder /opt/venv /opt/venv

# Not root. Cloud Run does not require it, but a compromised dependency should
# not be able to write to the image either.
RUN useradd --create-home --uid 1000 appuser
WORKDIR /app

# Into /app/backend/, not /app: main.py imports its siblings relatively
# ("from .database import ..."), so it has to be imported as a member of the
# `backend` package. Flattened into /app it raises at startup with
# "attempted relative import with no known parent package" and the container
# never binds a port.
COPY --chown=appuser:appuser . /app/backend/

USER appuser

# Documentation only — Cloud Run injects the real PORT and ignores this.
EXPOSE 8080

# Shell form so ${PORT} is expanded by the shell. In exec form the literal
# string "${PORT:-8080}" is passed to uvicorn, which fails to parse it as an
# int. `exec` replaces the shell so uvicorn is PID 1 and receives the SIGTERM
# Cloud Run sends to drain an instance.
CMD exec uvicorn backend.main:app --host 0.0.0.0 --port ${PORT:-8080}
