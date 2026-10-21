-- ============================================================
-- Migration 006: Workout Analyses Table
-- Status: PENDING / TO BE APPLIED
-- Stores granular 1km auto-splits, interval laps, deterministic metrics, and AI Coach reports.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.workout_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL,
    healthkit_workout_uuid TEXT NOT NULL UNIQUE,
    workout_type TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    distance_km NUMERIC(6, 2),
    duration_min NUMERIC(6, 1) NOT NULL,
    avg_pace_min_km NUMERIC(5, 2),
    avg_hr NUMERIC(4, 1),
    max_hr NUMERIC(4, 1),
    elevation_gain_m NUMERIC(6, 1),
    efficiency_factor NUMERIC(6, 3),
    aerobic_decoupling_pct NUMERIC(5, 2),
    splits_json JSONB DEFAULT '[]'::jsonb,
    laps_json JSONB DEFAULT '[]'::jsonb,
    ai_coach_report TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_workout_analyses_user ON public.workout_analyses(user_id);
CREATE INDEX IF NOT EXISTS idx_workout_analyses_hk_uuid ON public.workout_analyses(healthkit_workout_uuid);
CREATE INDEX IF NOT EXISTS idx_workout_analyses_started_at ON public.workout_analyses(user_id, started_at DESC);
