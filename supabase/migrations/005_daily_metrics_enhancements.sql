-- ============================================================
-- Migration 005: Enhance daily_metrics for Lifestyle & NEAT tracking
-- Status: PENDING
-- Adds distance_km and source columns to track non-exercise daily activity (steps, active kcal)
-- ============================================================

ALTER TABLE public.daily_metrics ADD COLUMN IF NOT EXISTS distance_km NUMERIC;
ALTER TABLE public.daily_metrics ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'apple_health';

CREATE INDEX IF NOT EXISTS idx_daily_metrics_user_date ON public.daily_metrics(user_id, metric_date DESC);
