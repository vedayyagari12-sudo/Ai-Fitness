-- Run in Supabase SQL editor

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

CREATE POLICY "Users can read own profile"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can upsert own profile"
  ON user_profiles FOR ALL
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can read own bodyweight logs"
  ON bodyweight_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own bodyweight logs"
  ON bodyweight_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Re-weighing on a day already logged is an UPDATE of that day's row, not a
-- new insert. Without these the first weigh-in of the day succeeded and every
-- correction after it was silently dropped by RLS (Postgrest reports a
-- policy-filtered UPDATE as 200 with an empty body, not as an error).
-- Safe to run on an existing database.
CREATE POLICY "Users can update own bodyweight logs"
  ON bodyweight_logs FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own bodyweight logs"
  ON bodyweight_logs FOR DELETE
  USING (auth.uid() = user_id);

-- ── Additive migrations (safe to re-run) ─────────────────────────────────────

-- The training split is written to the profile so it follows the account
-- across devices. Without this column that write fails and the choice only
-- ever lived in this device's local storage.
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS training_split TEXT;

-- Back detail from a physique scan. Null on scans with no back photo.
ALTER TABLE physique_scans ADD COLUMN IF NOT EXISTS lats_score FLOAT;
ALTER TABLE physique_scans ADD COLUMN IF NOT EXISTS mid_back_score FLOAT;
ALTER TABLE physique_scans ADD COLUMN IF NOT EXISTS traps_score FLOAT;

-- If workouts table uses integer user_id, migrate to UUID:
-- ALTER TABLE workouts ALTER COLUMN user_id TYPE TEXT USING user_id::TEXT;
