# Lifecore Development Roadmap

Development roadmap transitioning from MVP (`calories-bot-mvp`) to the full **Lifecore (Quantified Self Health & Nutrition Data Warehouse)** platform.

---

## ✅ Phase 1 — Telegram Bot: Nutrition & Weight (Completed)

- [x] **1.1.** AI food photo recognition via Gemini (`gemini-2.5-flash` → `gemini-3.6-flash` fallback).
- [x] **1.2.** Food quality taxonomy tags (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`).
- [x] **1.3.** Micronutrient estimation (`fiber_g`, `sodium_mg`, `potassium_mg`, `vitamin_c_mg`, `iron_mg`, `calcium_mg`).
- [x] **1.4.** Amino acid estimation (`bcaa_g`, `leucine_g`) for protein meals.
- [x] **1.5.** Deficit Buffer ×1.125 (+12.5% to calories; macronutrients remain exact).
- [x] **1.6.** 4-hour day shift (dietary day resets at 04:00 AM instead of midnight).
- [x] **1.7.** Command `/y` — log meals for yesterday (in both Node.js and Supabase Edge Function).
- [x] **1.8.** Command `/w <weight>` — body weight logging with dynamic delta calculation.
- [x] **1.9.** Command `/stats` — daily summary with diet quality breakdown and inline date navigation.
- [x] **1.10.** Persistent bottom keyboard (`📊 Statistics`, `⚖️ Log Weight`, `📅 Log for Yesterday`).
- [x] **1.11.** EXIF timestamp extraction from uncompressed food photos.
- [x] **1.12.** PostgreSQL database tables: `meals`, `body_measurements`.
- [x] **1.13.** Supabase Edge Function (Deno) — production webhook with full feature parity.
- [x] **1.14.** Merge `Lifecore/` analytics submodule into the unified repository.

---

## 🔜 Phase 2 — AI Coach: Workouts, Sleep & Recovery Analysis (Next)

### 2.1. Database
- [x] Apply migration `002_workouts.sql` in Supabase.
- [x] Apply migration `003_sleep_logs.sql` in Supabase.
- [x] Apply migration `004_fix_sleep_logs_nullable.sql` in Supabase.
- [x] Apply migration `005_daily_metrics_enhancements.sql` in Supabase.

### 2.2. Historical Data Archive Ingestion
- [x] Run `Lifecore/scripts/deep_health_analysis.py` → generate `daily_health_summary.json`.
- [x] Run `Lifecore/scripts/sync_to_supabase.py` → bulk-upload Apple Health & Strava history to Supabase (410 workouts, 1044 sleep logs, 1279 daily metrics, with deduplication).

### 2.3. Edge Function `ingest-health`
- [x] Create `supabase/functions/ingest-health/index.ts`.
- [x] Handle incoming JSON: `{ secret, user_id, daily_activity, sleep, workout }`.
- [x] Validate `INGEST_SECRET` against Supabase Secrets.
- [x] Upsert into `daily_metrics`, `sleep_logs`, and insert into `workouts`.
- [x] Deploy function: `supabase functions deploy ingest-health --no-verify-jwt --use-api`.
- [x] Set secret: `supabase secrets set INGEST_SECRET=...`.

### 2.4. iOS Telemetry Ingestion (Swift AppIntent & Shortcuts)
- [x] Specification reference: [`shortcuts/ingest_health_shortcut.md`](../shortcuts/ingest_health_shortcut.md).
- [x] Native Swift AppIntent implementation: [`ios/Lifecore/`](../ios/Lifecore/) (`HealthKitManager`, `HealthPayload`, `LifecoreSyncIntent`).
- [x] Read HealthKit data via Swift: HRV (SDNN), RHR, sleep stages (Core, Deep, REM) via `HKStatisticsQuery` & `HKSampleQuery`.
- [x] Read daily activity: steps, active kcal, walking distance.
- [x] Send POST request to `ingest-health` Edge Function via `URLSession`.
- [ ] Connect `LifecoreSyncIntent` in Xcode project and link to single-action iOS Automation (09:00 AM & Workout Ends).

### 2.5. Coach Prompt (`utils/coachPrompt.js`)
- [x] Implement `buildCoachContext(userId)` — queries 3-day history of workouts, sleep, nutrition, and daily NEAT activity.
- [x] Implement `buildCoachPrompt(context)` — builds structured prompt for Gemini with 4-part causal insights.
- [x] Response format: `SYSTEM STATE: 🟢/🟡/🔴` with up to 4 causal insights.
- [x] Guardrails: if HRV < baseline by >15% or RHR > baseline by >3 bpm → mandate recovery recommendation.

### 2.6. Coach Handler (`handlers/coachHandler.js`)
- [x] Command `/coach` → triggers `buildCoachContext` + Gemini analysis + Telegram response.
- [x] Multi-model fallback cascade with 25s timeout race (`gemini-2.5-flash`, `gemini-3.8-flash`, `gemini-3.6-flash`).
- [ ] Command `/workout <type> <minutes> [km, avg_hr]` — manual workout logging fallback.
- [ ] Command `/sleep <hours>` — manual sleep logging fallback (without Apple Watch).
- [x] Mirror logic into Supabase Edge Function `telegram-bot/index.ts`.

### 2.7. Update MAIN_KEYBOARD
- [x] Add `🏃 Аналіз тренування` button → `/coach`.
- [ ] Add `📋 Weekly Report` button → weekly summary digest.
- [x] Synchronize in both implementations: `utils/keyboard.js` + Edge Function.

---

## 📅 Phase 3 — Analytics & Correlation Engine (Post Phase 2)

### 3.1. Rolling Averages for Body Weight
- [ ] PostgreSQL function or Edge Function: compute `rolling_avg_weight_7d` and `rolling_avg_weight_14d`.
- [ ] Populate `daily_metrics` table upon every new weight measurement.
- [ ] Display true trend lines in `/stats` to eliminate daily water noise.

### 3.2. Time-Lagged Correlation (Python)
- [ ] Analyze impact of sodium intake (day T) on morning weight (day T+1, T+2).
- [ ] Analyze impact of evening carbohydrates on deep sleep duration.
- [ ] Analyze impact of calorie deficits on morning HRV trends.
- [ ] Analyze correlation between running mileage and Resting Heart Rate (overtraining signal).
- [ ] Pearson and Spearman correlation with statistical significance ($p < 0.05$).

### 3.3. Automated Morning Digest
- [ ] Supabase cron (Edge Function Scheduler) at 08:00 AM daily.
- [ ] Content: morning weight vs. 7-day trend, potential noise driver (sodium/glycogen), yesterday's macro summary, and daily training readiness based on HRV.

---

## 📅 Phase 4 — Multi-User & Profiles (Post Phase 3)

### 4.1. `users` Table
- [ ] Core user profile: age, height, baseline weight, fitness goal (deficit/surplus/recomposition).
- [ ] Target macros: `target_kcal`, `target_protein`, `target_carbs`, `target_fat`.
- [ ] Baseline biomarkers: baseline HRV and RHR for personalized thresholding.

### 4.2. Vika Profile
- [ ] Reference prompt ready: `Lifecore/prompts/antigravity_health_assistant_prompt_vika.md`.
- [ ] Add multi-tenant routing for secondary `ALLOWED_USER_ID` via `users` table.

### 4.3. Personalized Coach Prompt
- [ ] Ingest individual targets and baseline recovery markers from `users` table.
- [ ] Tailor recommendations to specific training goals (fat loss vs. recomposition vs. endurance).

---

## 📅 Phase 5 — Advanced AI Insights & Visualization (Long-Term)

### 5.1. Smart Natural Language Assistant
- [ ] Natural language queries: "Why did I gain 1 kg today?" → AI identifies dietary/water factors.
- [ ] "How did this week's diet affect my running pace?" → Time-lagged explanation.
- [ ] "Compare this week to last week" → Structured comparative digest.

### 5.2. BI Dashboard
- [ ] Connect Metabase or Apache Superset to Supabase PostgreSQL.
- [ ] Interactive dashboards: rolling weight + workouts + HRV + calories on unified timelines.

### 5.3. Native iOS Companion App (Future)
- [ ] SwiftUI + CoreBluetooth: capture smart scale measurements in the background without launching vendor apps.
- [ ] Direct bidirectional sync with HealthKit.

---

## Current Immediate Priorities

```
⭐ NOW:  Restore Supabase Project → Apply Migrations 002 & 003 → Run sync_to_supabase.py
⭐ NEXT: Deploy ingest-health Edge Function + Set up iOS Shortcut
⭐ THEN: Implement coachHandler & coachPrompt → Add 🏃 button to Telegram Bot menu
```
