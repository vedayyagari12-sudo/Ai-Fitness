-- Run in Supabase SQL editor.
--
-- Every statement here is idempotent, so the whole file can be re-run on an
-- existing database. Postgres has no CREATE POLICY IF NOT EXISTS, hence the
-- DROP POLICY IF EXISTS before each one — without that, re-running aborts on
-- the first existing policy and any later statements never execute.

CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  goal TEXT CHECK (goal IN ('bulk', 'cut', 'maintain', 'athletic')),
  gender TEXT,
  age INT,
  height_cm FLOAT,
  weight_kg FLOAT,
  workout_frequency TEXT,
  equipment TEXT,
  fitness_level TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bodyweight_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  weight_kg FLOAT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bodyweight_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own profile" ON user_profiles;
CREATE POLICY "Users can read own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can upsert own profile" ON user_profiles;
CREATE POLICY "Users can upsert own profile"
  ON user_profiles FOR ALL
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can read own bodyweight logs" ON bodyweight_logs;
CREATE POLICY "Users can read own bodyweight logs"
  ON bodyweight_logs FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own bodyweight logs" ON bodyweight_logs;
CREATE POLICY "Users can insert own bodyweight logs"
  ON bodyweight_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Re-weighing on a day already logged is an UPDATE of that day's row, not a
-- new insert. Without these the first weigh-in of the day succeeded and every
-- correction after it was silently dropped by RLS (Postgrest reports a
-- policy-filtered UPDATE as 200 with an empty body, not as an error).
-- Safe to run on an existing database.
DROP POLICY IF EXISTS "Users can update own bodyweight logs" ON bodyweight_logs;
CREATE POLICY "Users can update own bodyweight logs"
  ON bodyweight_logs FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own bodyweight logs" ON bodyweight_logs;
CREATE POLICY "Users can delete own bodyweight logs"
  ON bodyweight_logs FOR DELETE
  USING (auth.uid() = user_id);

-- ── Additive migrations (safe to re-run) ─────────────────────────────────────

-- ── Profile columns ─────────────────────────────────────────────────────────
--
-- Every profile column is (re)declared here, not just the ones added late.
--
-- The CREATE TABLE above is guarded by IF NOT EXISTS, which does exactly what
-- it says: on a database whose user_profiles table already exists, the whole
-- statement is skipped — including any column added to it since that table
-- was first created. So a column can be present in the CREATE, absent from
-- the real table, and nobody finds out until a write fails.
--
-- That is what happened to training_split, and it is not specific to it. An
-- account created before `equipment` or `fitness_level` was added to the
-- CREATE has neither, and saving either one fails with PGRST204 ("could not
-- find the column in the schema cache"). The app updates its local state
-- first and then hits that error, so the setting appears to save and reverts
-- on the next launch.
--
-- ADD COLUMN IF NOT EXISTS is idempotent, so listing all of them costs
-- nothing on an up-to-date database and repairs an old one.
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS goal TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS age INT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS height_cm FLOAT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS weight_kg FLOAT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS workout_frequency TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS equipment TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS fitness_level TEXT;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS training_split TEXT;

-- Confirms every profile column now exists. Expect nine rows.
--
--   SELECT column_name, data_type
--   FROM information_schema.columns
--   WHERE table_name = 'user_profiles'
--     AND column_name IN ('goal','gender','age','height_cm','weight_kg',
--                         'workout_frequency','equipment','fitness_level',
--                         'training_split')
--   ORDER BY column_name;

-- Back detail from a physique scan. Null on scans with no back photo.
ALTER TABLE physique_scans ADD COLUMN IF NOT EXISTS lats_score FLOAT;
ALTER TABLE physique_scans ADD COLUMN IF NOT EXISTS mid_back_score FLOAT;
ALTER TABLE physique_scans ADD COLUMN IF NOT EXISTS traps_score FLOAT;

-- Account deletion removes rows from these tables using the user's own JWT,
-- so each needs a DELETE policy. Without one Postgrest returns 204 having
-- deleted nothing — the same silent failure that hid the bodyweight bug, but
-- here it would leave a "deleted" account's data behind.
DROP POLICY IF EXISTS "Users can delete own calorie logs" ON calorie_logs;
CREATE POLICY "Users can delete own calorie logs"
  ON calorie_logs FOR DELETE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own physique scans" ON physique_scans;
CREATE POLICY "Users can delete own physique scans"
  ON physique_scans FOR DELETE
  USING (auth.uid() = user_id);

-- If workouts table uses integer user_id, migrate to UUID:
-- ALTER TABLE workouts ALTER COLUMN user_id TYPE TEXT USING user_id::TEXT;
