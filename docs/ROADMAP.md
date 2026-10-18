# Lifecore 2.0 Development Roadmap

> **Master Evolution Plan:** Transitioning from the Version 1.0 Telegram MVP to the **Native iOS-First & Athletic Performance Platform**.

---

## 🏛️ Phase 1 — Telegram Bot MVP & Data Foundations (Completed / Legacy)

- [x] **1.1. Food Photo Recognition:** Gemini Vision food parsing with macronutrient extraction.
- [x] **1.2. Food Taxonomy:** Quality tags (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`).
- [x] **1.3. Micronutrient Estimation:** Fiber, sodium, potassium, and amino acid estimation (`bcaa_g`, `leucine_g`).
- [x] **1.4. Deficit Buffer (+12.5%):** Guaranteed caloric buffer (`kcal * 1.125`).
- [x] **1.5. 4-Hour Day Shift:** Dietary reset at 04:00 AM instead of midnight.
- [x] **1.6. Supabase Cloud Database:** Relational tables: `meals`, `body_measurements`, `daily_metrics`, `sleep_logs`, `workouts`.
- [x] **1.7. Historical Data Ingestion:** Uploaded multi-year archive (410 workouts, 1044 sleep logs, 1279 daily metrics).
- [x] **1.8. Ingestion Webhook:** Deployed `ingest-health` Supabase Edge Function with secret authentication.
- [x] **1.9. Initial Swift AppIntent:** Created initial `ios/Lifecore/` Swift package for Apple Health telemetry push.

---

## 🚀 Phase 2 — Native iOS-First Platform & Athletic Engine (Active / Current Focus)

### 2.1. HealthKit Deep Telemetry Reader (Swift 6)
- [x] Implement async HealthKit statistics queries for sleep stages (`asleepDeep`, `asleepREM`, `asleepCore`, `awake`).
- [x] Implement morning autonomic biomarker queries (HRV SDNN, resting heart rate RHR).
- [ ] Implement `WorkoutSplitReader`: query continuous `HKQuantityTypeIdentifierDistanceWalkingRunning` and `HKQuantityTypeIdentifierHeartRate` samples to slice workouts into exact 1km splits.
- [ ] Implement elevation gain/loss per kilometer ($\Delta h$) via HealthKit route / workout metadata.
- [ ] Filter out non-athletic incidental sessions (5-min bike rides, 40-min casual walks) from deep athletic analysis while preserving them in daily NEAT energy.

### 2.2. Deterministic Swift Math Engine
- [x] Pure NEAT isolation formula: $\text{NEAT} = \max(0, \text{daily\_active\_kcal} - \sum \text{workout\_kcal})$.
- [ ] Implement on-device **Efficiency Factor ($EF$)**:
  $$EF = \frac{\text{Speed (m/min)}}{\text{Average Heart Rate (bpm)}}$$
- [ ] Implement on-device **Aerobic Decoupling & Cardiac Drift %**:
  $$\text{Cardiac Drift } (\%) = \left(\frac{EF_{\text{1st half}} - EF_{\text{2nd half}}}{EF_{\text{1st half}}}\right) \times 100\%$$
- [ ] Implement **7-day & 14-day Rolling Weight Averages** in Swift to filter acute water/glycogen noise.

### 2.3. SwiftUI Dashboard & Athletic UX (Bevel-Style)
- [x] Scaffold native SwiftUI application in `ios/Lifecore/`.
- [ ] **Today / Readiness View:**
  - Dynamic readiness score derived from HRV SDNN, RHR stability, and deep/REM sleep duration.
  - Interactive cardiovascular strain ring and nutrition balance ring.
- [ ] **Workout & Splits View:**
  - Interactive kilometer splits table (Pace, HR, Elevation, Cadence).
  - Synchronized Swift Charts displaying pace curves against heart rate and elevation profiles.
- [ ] **Longitudinal Trends View:**
  - Weight trend line overlaying raw weigh-ins with 7d/14d rolling averages.
  - Monthly HRV and RHR baseline trajectories.

### 2.4. AI Athletic Performance Analyst (Gemini API)
- [x] Draft **70 / 15 / 15** prompt architecture (RFC in `docs/RFC_WORKOUT_GRANULARITY_AND_COACH_ARCHITECTURE.md`).
- [ ] Integrate Gemini API client into iOS app (`LifecoreAIService.swift`).
- [ ] Implement prompt payload assembler passing pre-calculated splits, cardiac drift %, benchmark comparisons, and recovery context.
- [ ] Enforce elite sports analyst persona (zero generic wellness platitudes, zero medical panic).

### 2.5. In-App Vision Food Scanner
- [ ] Integrate native iOS camera scanner using AVFoundation.
- [ ] Implement optimistic UI: instant local entry creation while Gemini Vision analyzes portions and macros in the background.
- [ ] Auto-apply +12.5% deficit buffer and dietary date offset (04:00 AM).

### 2.6. SwiftData Offline-First Persistence & Supabase Sync
- [ ] Define `@Model` SwiftData classes for `MealEntity`, `WorkoutEntity`, `DailyMetricEntity`, and `SleepLogEntity`.
- [ ] Implement seamless two-way background synchronization with Supabase PostgreSQL via `LifecoreAPIService`.

---

## 📈 Phase 3 — Advanced Physiological Modeling & Time-Lags (Next)

### 3.1. Multi-Day Time-Lagged Correlations
- [ ] Quantify the impact of sodium intake (Day T) on morning fluid retention (Day T+1, T+2).
- [ ] Quantify the correlation between carbohydrate deficit and subsequent aerobic decoupling on endurance runs.
- [ ] Detect early overtraining signals via cumulative acute-to-chronic workload ratio (ACWR).

### 3.2. Automated Morning Briefing
- [ ] iOS Lock Screen Widget and notification at 08:00 AM:
  - Morning Readiness Score (HRV/RHR).
  - Recommended workout intensity for the day.
  - Target carbohydrate and hydration intake.

---

## ⌚️ Phase 4 — Hardware & Ecosystem Extensions (Future)

### 4.1. Bluetooth Smart Scale Integration
- [ ] CoreBluetooth background reader for direct scale weigh-ins (weight, impedance, body fat %).

### 4.2. WatchOS Native Companion App
- [ ] Dedicated Apple Watch complication and Action Button integration for instant readiness check and split tracking.
