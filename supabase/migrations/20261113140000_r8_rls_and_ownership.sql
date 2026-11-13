-- ============================================================
-- Migration R8: Row Level Security (RLS) & Account Ownership
-- Adds auth_user_id UUID to user tables, creates user_account_mappings,
-- enables RLS on all tables, and configures owner-only policies.
-- ============================================================

-- 1. Add auth_user_id UUID DEFAULT auth.uid() to all client telemetry & record tables
ALTER TABLE public.meals
    ADD COLUMN IF NOT EXISTS auth_user_id UUID DEFAULT auth.uid();
ALTER TABLE public.meals
    ALTER COLUMN auth_user_id SET DEFAULT auth.uid();

ALTER TABLE public.workout_analyses
    ADD COLUMN IF NOT EXISTS auth_user_id UUID DEFAULT auth.uid();
ALTER TABLE public.workout_analyses
    ALTER COLUMN auth_user_id SET DEFAULT auth.uid();

ALTER TABLE public.daily_metrics
    ADD COLUMN IF NOT EXISTS auth_user_id UUID DEFAULT auth.uid();
ALTER TABLE public.daily_metrics
    ALTER COLUMN auth_user_id SET DEFAULT auth.uid();

ALTER TABLE public.sleep_logs
    ADD COLUMN IF NOT EXISTS auth_user_id UUID DEFAULT auth.uid();
ALTER TABLE public.sleep_logs
    ALTER COLUMN auth_user_id SET DEFAULT auth.uid();

ALTER TABLE public.workouts
    ADD COLUMN IF NOT EXISTS auth_user_id UUID DEFAULT auth.uid();
ALTER TABLE public.workouts
    ALTER COLUMN auth_user_id SET DEFAULT auth.uid();

ALTER TABLE public.body_measurements
    ADD COLUMN IF NOT EXISTS auth_user_id UUID DEFAULT auth.uid();
ALTER TABLE public.body_measurements
    ALTER COLUMN auth_user_id SET DEFAULT auth.uid();

ALTER TABLE public.activities
    ADD COLUMN IF NOT EXISTS auth_user_id UUID DEFAULT auth.uid();
ALTER TABLE public.activities
    ALTER COLUMN auth_user_id SET DEFAULT auth.uid();

-- 2. Create user_account_mappings for legacy Telegram/Postgres bigint <-> Supabase auth UUID resolution
CREATE TABLE IF NOT EXISTS public.user_account_mappings (
    auth_user_id UUID NOT NULL,
    legacy_user_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (auth_user_id, legacy_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_account_mappings_legacy
    ON public.user_account_mappings(legacy_user_id);

-- 3. Create indexes on auth_user_id for low-latency RLS filter execution
CREATE INDEX IF NOT EXISTS idx_meals_auth_user_id
    ON public.meals(auth_user_id);

CREATE INDEX IF NOT EXISTS idx_workout_analyses_auth_user_id
    ON public.workout_analyses(auth_user_id);

CREATE INDEX IF NOT EXISTS idx_daily_metrics_auth_user_id
    ON public.daily_metrics(auth_user_id);

CREATE INDEX IF NOT EXISTS idx_sleep_logs_auth_user_id
    ON public.sleep_logs(auth_user_id);

CREATE INDEX IF NOT EXISTS idx_workouts_auth_user_id
    ON public.workouts(auth_user_id);

CREATE INDEX IF NOT EXISTS idx_body_measurements_auth_user_id
    ON public.body_measurements(auth_user_id);

CREATE INDEX IF NOT EXISTS idx_activities_auth_user_id
    ON public.activities(auth_user_id);

-- 4. Enable Row Level Security (RLS) across all tables
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sleep_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.body_measurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_account_mappings ENABLE ROW LEVEL SECURITY;

-- 5. Owner-only policies: deny anon, allow authenticated owner (auth.uid() = auth_user_id)
DROP POLICY IF EXISTS "meals_owner_policy" ON public.meals;
CREATE POLICY "meals_owner_policy" ON public.meals
    FOR ALL
    TO authenticated
    USING (auth.uid() = auth_user_id)
    WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "workout_analyses_owner_policy" ON public.workout_analyses;
CREATE POLICY "workout_analyses_owner_policy" ON public.workout_analyses
    FOR ALL
    TO authenticated
    USING (auth.uid() = auth_user_id)
    WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "daily_metrics_owner_policy" ON public.daily_metrics;
CREATE POLICY "daily_metrics_owner_policy" ON public.daily_metrics
    FOR ALL
    TO authenticated
    USING (auth.uid() = auth_user_id)
    WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "sleep_logs_owner_policy" ON public.sleep_logs;
CREATE POLICY "sleep_logs_owner_policy" ON public.sleep_logs
    FOR ALL
    TO authenticated
    USING (auth.uid() = auth_user_id)
    WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "workouts_owner_policy" ON public.workouts;
CREATE POLICY "workouts_owner_policy" ON public.workouts
    FOR ALL
    TO authenticated
    USING (auth.uid() = auth_user_id)
    WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "body_measurements_owner_policy" ON public.body_measurements;
CREATE POLICY "body_measurements_owner_policy" ON public.body_measurements
    FOR ALL
    TO authenticated
    USING (auth.uid() = auth_user_id)
    WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "activities_owner_policy" ON public.activities;
CREATE POLICY "activities_owner_policy" ON public.activities
    FOR ALL
    TO authenticated
    USING (auth.uid() = auth_user_id)
    WITH CHECK (auth.uid() = auth_user_id);

-- Client can only read their own verified mapping; inserts/updates are strictly service_role only (never trust client to assign legacy ownership).
DROP POLICY IF EXISTS "user_account_mappings_owner_policy" ON public.user_account_mappings;
DROP POLICY IF EXISTS "user_account_mappings_read_own_policy" ON public.user_account_mappings;
CREATE POLICY "user_account_mappings_read_own_policy" ON public.user_account_mappings
    FOR SELECT
    TO authenticated
    USING (auth.uid() = auth_user_id);
