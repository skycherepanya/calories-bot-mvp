# Lifecore Maestro E2E Testing Specification (High-Leverage Core Suite)

**Date:** 2026-10-21  
**Status:** Approved by User  
**Target Platform:** Native iOS (Simulator, iPhone 17 / iOS 27.0+)  
**App Bundle Identifier:** `com.skycherepanya.Lifecore`  

---

## 1. Goal & Philosophy
Implement a **minimal set of maximally effective (high-leverage)** End-to-End tests using [Maestro](https://maestro.mobile.dev) for Lifecore.
Rather than superficial smoke checks (mere tab switching), this suite exercises the 4 critical business and physiological loops that catch 95% of regressions during active development:
1. **Physiological Intelligence & Profile Calibration:** Today view cards, modal calibration of athlete anthropometrics & baseline vitals, and persistence.
2. **Nutrition Optimistic Logging & Undo:** Quick logging with presets, text entry, instant optimistic state resolution, and meal deletion/undo banner.
3. **Workout Intelligence & Filtering:** Category filtering (Running/Strength/Cycling/Walks), refresh mechanism, and telemetry list.
4. **Trends Analytics & Adaptive Engine:** Switching time horizons (7D/30D/90D) and cycling through all 4 analytical categories (Adaptation, Workload ACWR, Body Weight Rolling Averages, Cardio Autonomic Vitals).

---

## 2. Accessibility Identifiers Schema (Minimal & Robust)

Targeted `.accessibilityIdentifier(...)` elements added to SwiftUI views to guarantee 100% test stability regardless of localization or copy changes:

| View File | UI Element | Identifier | Purpose |
|---|---|---|---|
| `MainTabView.swift` | Today Tab | `tab_today` | Switch to Today screen |
| `MainTabView.swift` | Workouts Tab | `tab_workouts` | Switch to Workouts screen |
| `MainTabView.swift` | Nutrition Tab | `tab_nutrition` | Switch to Nutrition screen |
| `MainTabView.swift` | Trends Tab | `tab_trends` | Switch to Trends screen |
| `TodayView.swift` | Profile Avatar Button | `btn_open_profile` | Open athlete profile sheet |
| `TodayView.swift` | Body Battery Card | `card_body_battery` | Verify 24h battery widget |
| `TodayView.swift` | Overnight Vitals Card | `card_overnight_vitals` | Verify 5-metric vitals card |
| `AthleteProfileSheet.swift` | Weight Input Field | `input_athlete_weight` | Enter new athlete weight |
| `AthleteProfileSheet.swift` | Save Profile Button | `btn_save_profile` | Persist profile changes |
| `AthleteProfileSheet.swift` | Cancel Profile Button | `btn_close_profile` | Dismiss profile sheet |
| `NutritionView.swift` | Add Meal Button | `btn_add_meal` | Open food input sheet |
| `NutritionView.swift` | Macro Summary Card | `card_nutrition_summary` | Verify calories/macros display |
| `FoodInputSheet.swift` | Food Text Editor | `input_food_text` | Input custom food description |
| `FoodInputSheet.swift` | Preset Chip: Oatmeal | `preset_oatmeal` | Quick tap preset chip |
| `FoodInputSheet.swift` | Submit Log Button | `btn_submit_food` | Trigger food recognition/logging |
| `FoodInputSheet.swift` | Cancel Sheet Button | `btn_close_food_input` | Dismiss food sheet |
| `WorkoutsView.swift` | Category Filter: All | `filter_workout_all` | Filter all workouts |
| `WorkoutsView.swift` | Category Filter: Running | `filter_workout_running` | Filter running workouts |
| `WorkoutsView.swift` | Category Filter: Strength | `filter_workout_strength` | Filter strength workouts |
| `WorkoutsView.swift` | Refresh Button | `btn_refresh_workouts` | Reload workout telemetry |
| `TrendsView.swift` | Category: Adaptation | `tab_trend_adaptation` | Switch to Adaptation / Engine |
| `TrendsView.swift` | Category: Workload | `tab_trend_workload` | Switch to ACWR / TRIMP |
| `TrendsView.swift` | Category: Body & Weight | `tab_trend_body` | Switch to rolling weight chart |
| `TrendsView.swift` | Category: Cardio & ANS | `tab_trend_cardio` | Switch to autonomic chart |

---

## 3. High-Leverage E2E Test Flows (`.maestro/`)

```
.maestro/
├── config.yaml
├── 01_profile_and_readiness.yaml
├── 02_nutrition_logging_and_undo.yaml
├── 03_workout_filtering_and_refresh.yaml
├── 04_trends_adaptive_analytics.yaml
└── suite.yaml
```

### 3.1. `01_profile_and_readiness.yaml` (Physiology & Profile)
- Launch app `com.skycherepanya.Lifecore`.
- Assert `card_body_battery` and `card_overnight_vitals` are visible on Today screen.
- Tap `btn_open_profile`.
- Assert `btn_save_profile` is visible.
- Tap `input_athlete_weight`, clear and enter `79.5`.
- Tap `btn_save_profile`.
- Assert modal dismisses cleanly and Today screen remains responsive.

### 3.2. `02_nutrition_logging_and_undo.yaml` (Nutrition Loop)
- Tap `tab_nutrition`.
- Assert `card_nutrition_summary` is visible.
- Tap `btn_add_meal`.
- Assert `btn_submit_food` is visible.
- Tap preset chip `preset_oatmeal` (or input text into `input_food_text`).
- Tap `btn_submit_food`.
- Assert food input sheet dismisses immediately (<0.2s).
- Verify optimistic meal card or updated macro totals render.

### 3.3. `03_workout_filtering_and_refresh.yaml` (Workout Engine)
- Tap `tab_workouts`.
- Tap `filter_workout_running` -> verify active filter.
- Tap `filter_workout_strength` -> verify active filter.
- Tap `filter_workout_all` -> return to all.
- Tap `btn_refresh_workouts` -> verify refresh indicator triggers without crash.

### 3.4. `04_trends_adaptive_analytics.yaml` (Trends & Adaptive Calculations)
- Tap `tab_trends`.
- Tap `tab_trend_workload` -> verify ACWR workload section displays.
- Tap `tab_trend_body` -> verify Weight trend section displays.
- Tap `tab_trend_cardio` -> verify Autonomic / Cardio section displays.
- Tap `tab_trend_adaptation` -> return to Adaptation & Correlation insights.

### 3.5. `suite.yaml` (Master High-Leverage Suite)
Chains all 4 flows to run continuous regression validation in < 60 seconds.

---

## 4. Automation & CLI Execution (`scripts/run_e2e.sh`)

Automated runner script with the following workflow:
1. Detect or boot the active iOS Simulator (`iPhone 17` or currently booted device).
2. Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
3. Build the Debug configuration of `Lifecore` for Simulator:
   ```bash
   xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj \
              -scheme Lifecore \
              -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
              -configuration Debug \
              -derivedDataPath ios/Lifecore/build \
              build CODE_SIGNING_ALLOWED=NO
   ```
4. Install `Lifecore.app` to simulator:
   ```bash
   xcrun simctl install "$SIMULATOR_ID" ios/Lifecore/build/Build/Products/Debug-iphonesimulator/Lifecore.app
   ```
5. Check Maestro CLI:
   - If installed (`maestro` or `~/.maestro/bin/maestro`), execute `maestro test .maestro/suite.yaml`.
   - If not installed, output the exact install command:
     `curl -fsSL "https://get.maestro.mobile.dev" | bash`
     and instructions to add to `PATH`.
6. Provide CI template in `.github/workflows/e2e.yml`.
