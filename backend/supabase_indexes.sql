-- Performance indexes for the read paths behind /dashboard and /streak.
--
-- Safe to run repeatedly: every statement is IF NOT EXISTS, and creating an
-- index that already exists is a no-op rather than an error.
--
-- WHY THESE AND NOT OTHERS
--
-- Every one of these tables is read the same way: filter by user_id, filter
-- or sort by created_at. A single-column index on user_id alone cannot serve
-- that shape. Postgres can use it to locate the user's rows, but must then
-- fetch every one of them, discard the ones outside the date window, and
-- sort what survives — so the work grows with the user's ENTIRE history
-- rather than with the window actually requested. A user with two years of
-- meals pays for two years of rows on every dashboard load.
--
-- A composite index in (user_id, created_at) order answers the filter
-- directly and hands back rows already in created_at order, which removes
-- the sort as well. Column order matters: (created_at, user_id) would not
-- work, because the leading column has to be the one tested for equality.
--
-- CONCURRENTLY keeps the tables readable and writable while these build. It
-- cannot run inside a transaction block, so if your client wraps statements
-- in one, run them one at a time — or drop CONCURRENTLY, which is fine on
-- tables this small and simply locks writes for the moment it takes.

-- Meals: /dashboard reads the last 7 days; /streak reads all of them.
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_calorie_logs_user_created
  ON calorie_logs (user_id, created_at DESC);

-- Bodyweight: /dashboard reads the last 30 days, ordered.
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_bodyweight_logs_user_created
  ON bodyweight_logs (user_id, created_at DESC);

-- Physique scans: read in full, ordered by date.
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_physique_scans_user_created
  ON physique_scans (user_id, created_at DESC);

-- Workouts. This table is reached through SQLAlchemy rather than PostgREST,
-- and the model now declares the same index — but declaring it only creates
-- it for a table that does not exist yet. `Base.metadata.create_all` never
-- alters a table it finds already there, so an existing deployment needs
-- this statement; without it the model and the database disagree silently.
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_workouts_user_id_created_at
  ON workouts (user_id, created_at DESC);

-- user_profiles is queried by `id`, which is its PRIMARY KEY and therefore
-- already indexed. Nothing to add, and adding one would only cost writes.

-- ── Verify ──────────────────────────────────────────────────────────────────
-- Confirms all four exist. Expect four rows.
--
--   SELECT tablename, indexname
--   FROM pg_indexes
--   WHERE indexname IN (
--     'ix_calorie_logs_user_created',
--     'ix_bodyweight_logs_user_created',
--     'ix_physique_scans_user_created',
--     'ix_workouts_user_id_created_at'
--   )
--   ORDER BY tablename;
--
-- To confirm one is actually being USED rather than merely present, run the
-- planner against a real query and look for an Index Scan, not a Seq Scan:
--
--   EXPLAIN ANALYZE
--   SELECT created_at, calories FROM calorie_logs
--   WHERE user_id = '<a real user id>'
--     AND created_at >= now() - interval '7 days';
--
-- On a table with few rows Postgres may still choose a sequential scan
-- because it is genuinely cheaper there. That is correct behaviour, not a
-- failed index — it will switch over as the table grows.
