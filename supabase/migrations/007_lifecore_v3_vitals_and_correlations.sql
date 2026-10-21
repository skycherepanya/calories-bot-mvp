-- Migration 007: Lifecore 3.0 Overnight Vitals, Immune Radar, EWMA ACWR & Body Battery
ALTER TABLE sleep_logs
    ADD COLUMN IF NOT EXISTS hrv_rmssd_ms NUMERIC(5, 1),
    ADD COLUMN IF NOT EXISTS wrist_temp_delta_c NUMERIC(4, 2),
    ADD COLUMN IF NOT EXISTS spo2_pct NUMERIC(4, 1),
    ADD COLUMN IF NOT EXISTS respiratory_rate NUMERIC(4, 1),
    ADD COLUMN IF NOT EXISTS sleep_efficiency_pct NUMERIC(4, 1),
    ADD COLUMN IF NOT EXISTS immune_state TEXT DEFAULT 'optimal';

ALTER TABLE daily_metrics
    ADD COLUMN IF NOT EXISTS trimp_score NUMERIC(6, 1),
    ADD COLUMN IF NOT EXISTS ewma_acute_load NUMERIC(6, 1),
    ADD COLUMN IF NOT EXISTS ewma_chronic_load NUMERIC(6, 1),
    ADD COLUMN IF NOT EXISTS acwr_ratio NUMERIC(4, 2),
    ADD COLUMN IF NOT EXISTS body_battery_wake INTEGER,
    ADD COLUMN IF NOT EXISTS body_battery_min INTEGER;
