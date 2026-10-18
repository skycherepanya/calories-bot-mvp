-- ============================================================
-- Migration 004: Make total_hours nullable in sleep_logs
-- Status: PENDING
-- Allows inserting recovery biomarkers (HRV, RHR) when total sleep duration is absent
-- ============================================================

ALTER TABLE public.sleep_logs ALTER COLUMN total_hours DROP NOT NULL;
