# Lifecore Native iOS Client (`ios/Lifecore/`)

> **Platform:** iOS 17.0+ (Optimized for iOS 18+ & watchOS)  
> **Toolchain:** Swift 6, SwiftUI, Swift Charts, HealthKit, SwiftData, AppIntents

---

## 1. Overview & Capabilities

The `ios/Lifecore/` directory houses the primary client and physiological engine of the Lifecore platform. It operates local-first, querying continuous biometrics from Apple Watch via Apple HealthKit in under 5ms, computing deterministic sports and recovery math on-device, and rendering a Liquid Glass Bento Cockpit UI.

### Key Architecture Modules:
- **`App/`**: `LifecoreApp.swift` (lifecycle, SwiftData container initialization) and `MainTabView.swift` (4 primary tabs: `Сьогодні`, `Тренування`, `Харчування`, `Тренди`).
- **`Core/HealthKit/`**:
  - `HealthKitManager.swift`: Async queries for sleep stages, beat-to-beat `HKHeartbeatSeriesSample` (RMSSD), nocturnal RHR, wrist temperature ($\Delta T^\circ\text{C}$), $\text{SpO}_2\%$, respiratory rate, and bidirectional dietary write-back/deletion sync with `LifecoreMealID` metadata.
  - `WorkoutTelemetryExtractor.swift`: Continuous series sample extraction (heart rate, GPS distance, altitude, cadence).
- **`Core/MathEngine/`**:
  - `AdaptivePhysiologyEngine.swift` (v3.1): 4 self-learning loops (Bayesian shrinkage $w_N$, MacroFactor-style dynamic TDEE & adaptive BMR, online Ridge OLS $\beta$-sensitivities, 60d EWMA corridors & 1-tap RPE calibration).
  - `VitalsAndIllnessEngine.swift`: 5-metric nocturnal corridor analysis & Stanford NightSignal + Apple Vitals illness prodrome state machine.
  - `TrainingLoadAndBatteryEngine.swift`: Banister TRIMP, 7d/28d EWMA ACWR, and continuous 24h Body Battery (0–100%).
  - `CorrelationEngine.swift`: Point-biserial ($r_{pb}$) and Pearson ($r$) multi-day time-lagged correlations ($T+0, T+1, T+2$) with high-TRIMP confounder filtering.
  - `WorkoutMathEngine.swift`: 1km auto-splits, structured interval laps, Efficiency Factor ($EF$), and Cardiac Drift %.
  - `ReadinessCalculator.swift`: Recovery score (0–100%), cardiovascular strain score, and 7d/14d rolling weight averages.
  - `MathEngineVerification.swift`: 11 automated verification test suites for all mathematical engines.
- **`Core/UI/`**: `LifecoreDesignSystem.swift` (Liquid Glass Bento Cockpit, specular top-edge highlights, semantic status glow pills, `.lifecoreGlassCard()`).
- **`Core/Storage/`**:
  - `SwiftDataModels.swift`: `@Model` entities (`MealEntity`, `WorkoutAnalysisEntity`).
  - `AthleteProfileStore.swift`: User-editable physiological baselines, active move targets, and macro distribution.
  - `MealStorageService.swift`: SwiftData meal repository, optimistic UI state management, 5-second undo toast, and automatic HealthKit sync trigger.
  - `SupabaseSyncService.swift`: Direct native iOS REST client for bidirectional synchronization with Supabase PostgreSQL (meals, workout analyses, daily metrics, sleep logs).
- **`Core/AI/`**: `GeminiService.swift`, `FoodPrompt.swift`, `CoachPrompt.swift` (multi-model cascade for vision food parsing and 70/15/15 AI athletic performance analyst).
- **`Features/`**:
  - `Today/`: Hero Cockpit, `AdaptiveEngineBadgeBar`, `RPEQuickCalibrationRow`, Readiness/Strain/Active Move rings, `OvernightVitalsCard`, and `EnergyBankCard`.
  - `Workouts/`: Filterable workout lists with live TRIMP badges, granular split details, and synchronized charts.
  - `Nutrition/`: Unified «Записати їжу» entry point, two-tier zero-lag modal (`FoodInputSheet`), and in-place gesture swipe-to-delete (`SwipeableMealCardContainer`).
  - `Trends/`: Segmented Glass Switcher (`Адаптація`, `Навантаження`, `Тіло & Вага`, `Кардіо & ВНС`), Adaptive Engine status card, longitudinal rolling weight trends, autonomic envelopes, and Correlation Hub.
- **`Intents/`**: `LogMealIntent.swift` (hands-free Siri / Action button logger) and `LifecoreSyncIntent.swift` (system-wide background and manual HealthKit synchronization).

---

## 2. Xcode Setup & Build Configuration

1. Open `ios/Lifecore/Lifecore/Lifecore.xcodeproj` in **Xcode 16+**.
2. **Capabilities Required:**
   - **HealthKit:** Enable background delivery and clinical health records if needed.
   - **AppIntents:** Enabled by default in iOS 17+.
3. **Target Signing:** Ensure development team is selected and bundle identifier (`com.skycherepanya.Lifecore`) is configured.
4. **Execution:** Build and run on a physical iPhone paired with an Apple Watch Ultra/Series 8+ for real nocturnal wrist temperature and heartbeat series samples.
