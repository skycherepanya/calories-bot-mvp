# Lifecore Maestro E2E Testing Specification

**Date:** 2026-10-21  
**Status:** Approved by User  
**Target Platform:** Native iOS (Simulator, iPhone 17/iOS 27.0+)  
**App Bundle Identifier:** `com.skycherepanya.Lifecore`  

---

## 1. Goal & Objectives
Provide a lean, rock-solid End-to-End (E2E) testing suite using [Maestro](https://maestro.mobile.dev) for the Lifecore native iOS app.
The suite focuses strictly on the minimal essential smoke tests and critical user paths without adding runtime bloat or altering existing business logic:
1. **Zero Architecture Impact:** Zero third-party SDKs, Swift Packages, or binary overhead in production code.
2. **Deterministic Selectors:** Targeted `.accessibilityIdentifier(...)` on 5-6 core views for 100% resilience against localization and copy changes.
3. **Essential Smoke & Flow Coverage:**
   - App Launch & Tab Navigation (`Today` -> `Workouts` -> `Nutrition` -> `Trends`).
   - Nutrition Quick Logging modal (Open, type text, dismiss).
   - Athlete Profile modal (Open from Today, verify sheet, dismiss).
4. **Developer-First Local Runner:** An automated script (`scripts/run_e2e.sh`) that builds the app with `xcodebuild`, boots the simulator, installs the app, and runs Maestro tests with detailed pass/fail reporting.

---

## 2. Accessibility Identifiers Schema

The following SwiftUI views receive `.accessibilityIdentifier(...)`:

| View File | UI Element | Identifier | Purpose |
|---|---|---|---|
| `MainTabView.swift` | Today Tab Item | `tab_today` | Navigation assertion & tab switch |
| `MainTabView.swift` | Workouts Tab Item | `tab_workouts` | Navigation assertion & tab switch |
| `MainTabView.swift` | Nutrition Tab Item | `tab_nutrition` | Navigation assertion & tab switch |
| `MainTabView.swift` | Trends Tab Item | `tab_trends` | Navigation assertion & tab switch |
| `TodayView.swift` | Profile Avatar / Button | `btn_open_profile` | Open athlete profile sheet |
| `AthleteProfileSheet.swift` | Profile Sheet Container | `sheet_athlete_profile` | Verify profile modal visible |
| `AthleteProfileSheet.swift` | Close / Done Button | `btn_close_profile` | Dismiss profile modal |
| `NutritionView.swift` | Add Meal Button | `btn_add_meal` | Open food logging sheet |
| `FoodInputSheet.swift` | Food Input Container | `sheet_food_input` | Verify modal visible |
| `FoodInputSheet.swift` | Food Input Text Editor | `input_food_text` | Simulate entering meal description |
| `FoodInputSheet.swift` | Close Button | `btn_close_food_input` | Dismiss modal |
| `WorkoutsView.swift` | Workouts List Container | `list_workouts` | Verify workouts screen content |
| `TrendsView.swift` | Trends Scroll Container | `trends_scroll_view` | Verify trends screen content |

---

## 3. Maestro Flows Structure (`.maestro/`)

```
.maestro/
├── config.yaml
├── 01_smoke_navigation.yaml
├── 02_food_logging_modal.yaml
├── 03_today_profile_modal.yaml
└── suite.yaml
```

### 3.1. `config.yaml`
```yaml
appId: com.skycherepanya.Lifecore
```

### 3.2. Flow 1: `01_smoke_navigation.yaml` (App Launch & Tab Navigation)
- Launch app `com.skycherepanya.Lifecore`
- Assert `tab_today` is visible
- Tap `tab_workouts` -> Assert `list_workouts` is visible
- Tap `tab_nutrition` -> Assert `btn_add_meal` is visible
- Tap `tab_trends` -> Assert `trends_scroll_view` is visible
- Tap `tab_today` -> Return to initial state

### 3.3. Flow 2: `02_food_logging_modal.yaml` (Nutrition Logging Interaction)
- Launch app
- Tap `tab_nutrition`
- Assert `btn_add_meal` is visible
- Tap `btn_add_meal`
- Assert `sheet_food_input` is visible
- Tap `input_food_text`
- Input text: `"200g Greek yogurt with blueberries"`
- Tap `btn_close_food_input`
- Assert `sheet_food_input` is not visible

### 3.4. Flow 3: `03_today_profile_modal.yaml` (Athlete Profile Sheet)
- Launch app
- Tap `tab_today`
- Tap `btn_open_profile`
- Assert `sheet_athlete_profile` is visible
- Tap `btn_close_profile`
- Assert `sheet_athlete_profile` is not visible

### 3.5. `suite.yaml` (Master Runner)
Runs all 3 flows sequentially for end-to-end regression validation.

---

## 4. Execution & Automation Architecture (`scripts/run_e2e.sh`)

Bash automation script that:
1. Detects available simulator (defaults to booted simulator or `iPhone 17`).
2. Configures `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
3. Builds the `Lifecore` target for `platform=iOS Simulator`:
   ```bash
   xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj \
              -scheme Lifecore \
              -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
              -configuration Debug \
              -derivedDataPath ios/Lifecore/build \
              build CODE_SIGNING_ALLOWED=NO
   ```
4. Installs the built `Lifecore.app` into the target simulator via `xcrun simctl install`.
5. Checks if `maestro` CLI is installed (`~/.maestro/bin/maestro` or in `PATH`):
   - If missing, outputs friendly installation instructions (`curl -fsSL "https://get.maestro.mobile.dev" | bash`).
6. Executes `maestro test .maestro/suite.yaml`.

---

## 5. Verification & Non-Functional Requirements
- **Execution Time:** Entire suite runs in < 45 seconds on simulator.
- **Independence:** Each test flow can be executed standalone:
  `maestro test .maestro/01_smoke_navigation.yaml`
- **Zero Flakiness:** All selector queries use dedicated `id` attributes rather than variable localized labels.
- **Clean Git State:** Build artifacts in `ios/Lifecore/build/` are ignored in `.gitignore`.
