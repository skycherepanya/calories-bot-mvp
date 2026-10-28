# Lifecore v3.3 Design Spec: Hallmark v2.0.0 Bevel & Apple Health Daylight UI Redesign

**Date:** 2026-10-26  
**Version:** Lifecore v3.3 (Phase 3.3)  
**Target Platform:** Native iOS (Swift 6, SwiftUI, Swift Charts, HealthKit, SwiftData)  
**Design Standard:** Hallmark v2.0.0 (`scope: app`, `redesign: full`, Theme: Bevel Daylight)  
**Execution Profile:** Atomic, strictly-typed 6-Task architecture engineered for zero-ambiguity execution via direct implementation or Flash subagent-driven development.

---

## 1. Executive Summary & Hallmark Floor Audit

**Lifecore v3.3** performs a full Hallmark v2.0.0 redesign of the iOS client (`ios/Lifecore/`), transitioning from the dark void neon theme (`Liquid Glass Dark 3.0`) to a warm, tactile, daylight-first **Bevel & Apple Health** aesthetic (`Bevel Daylight 3.3`).

### 1.1. Hallmark Pre-Flight Findings (What Was Broken / Generated-Looking)
1. **Card-in-Card Nesting (Hallmark Floor 11 / Gate 4):**
   - `TodayView`: `BevelRingView` boxes inside `ringsHeaderView` card.
   - `OvernightVitalsCard`: `IllnessRadarBanner` + 5 `VitalsCorridorPill` cards nested inside an outer card.
   - `AdaptiveEngineStatusCard`: 4 `sensitivityCell` boxes nested inside an outer card.
   - `CorrelationInsightsCard`: `insightRow` boxes nested inside an outer card.
2. **Simultaneous Border + Drop Shadow + Specular Glow (Gate F24, Gate 29):**
   - `LifecoreGlassCardModifier` stacked `.ultraThinMaterial`, a 3-stop `specularBorderGradient`, colored borders, and a heavy black drop shadow (`radius: 10, y: 5`).
3. **Un-tokened Rainbow Literals (Floor 1, Gate 2a, Gate 23):**
   - Views bypassed `LifecoreTheme` with literal `Color(red: 0.05, green: 0.06, blue: 0.08)`, `Color(red: 0.1, green: 0.11, blue: 0.15)`, `.cyan`, `.purple`, `.orange`, `.green`, `.indigo`, and `.white` text that breaks in light mode.
4. **Tracked ALL-CAPS Eyebrows & Emoji Statuses (Floor 9, Floor 10, Floor 11):**
   - Uppercase eyebrows (`"СЬОГОДНІШНЯ АКТИВНІСТЬ"`, `"СЬОГОДНІ • ..."`, `"ЗАВТРА"`).
   - Emojis as UI icons (`"✅ Оптимальний..."`, `"⚠️ Дефіцит..."`, `"💧 Водний сплеск"`).
   - Middle-dot glued meta strings (`"45 хв • ~8.2 км • Z2"`).

### 1.2. What Stays 100% Untouched (The Wiring & Math)
- All deterministic Swift 6 engines (`ReadinessCalculator`, `WorkoutMathEngine`, `VitalsAndIllnessEngine`, `TrainingLoadAndBatteryEngine`, `CorrelationEngine`, `AdaptivePhysiologyEngine`, `TrainingPrescriptionEngine`).
- All 17 Maestro E2E `.accessibilityIdentifier(...)` hooks across `.maestro/01..05`.

---

## 2. Design System Specification (`LifecoreDesignSystem.swift`)

### 2.1. Hallmark Token Palette (Bevel & Apple Health Warm Daylight)
Every color across the app MUST reference `LifecoreTheme` tokens (Hallmark Floor 1):

| Token Name | Role / Surface Rung | RGB / Value | Hex Equivalent |
|---|---|---|---|
| `paperCanvas` | Rung 0: Main screen background (Warm Alabaster) | `Color(red: 0.965, green: 0.961, blue: 0.945)` | `#F6F5F1` |
| `paperCard` | Rung 1: Elevated section surface (Pure Warm White) | `Color(red: 1.000, green: 1.000, blue: 1.000)` | `#FFFFFF` |
| `paperWell` | Rung 2: Recessed inner well / interactive slot (No border) | `Color(red: 0.937, green: 0.929, blue: 0.902)` | `#EFECE6` |
| `ruleHairline` | Rung 3: `1px` structural divider & card stroke | `Color(red: 0.894, green: 0.882, blue: 0.855)` | `#E4E1DA` |
| `inkPrimary` | Primary headline & metric numerals (Deep Obsidian) | `Color(red: 0.078, green: 0.082, blue: 0.094)` | `#141518` |
| `inkSecondary` | Body copy & row labels | `Color(red: 0.345, green: 0.357, blue: 0.388)` | `#585B63` |
| `inkTertiary` | Units, axis labels, subtle timestamps | `Color(red: 0.545, green: 0.557, blue: 0.588)` | `#8B8E96` |
| `accentPrimary` | Primary interactive signal & active tab (Bevel Emerald) | `Color(red: 0.067, green: 0.600, blue: 0.365)` | `#11995D` |
| `accentIndigo` | Sleep & parasympathetic VNS signal (Apple Health Indigo) | `Color(red: 0.310, green: 0.275, blue: 0.898)` | `#4F46E5` |
| `accentTeal` | Aerobic efficiency & workload secondary metric | `Color(red: 0.055, green: 0.545, blue: 0.659)` | `#0E8BA8` |
| `statusOptimal` | Semantic Optimal / Recovery state | `Color(red: 0.067, green: 0.600, blue: 0.365)` | `#11995D` |
| `statusWarning` | Semantic Strain / Amber watch / Calorie flame | `Color(red: 0.851, green: 0.467, blue: 0.024)` | `#D97706` |
| `statusDanger` | Semantic Outlier / Illness prodrome / HR peak | `Color(red: 0.863, green: 0.149, blue: 0.149)` | `#DC2626` |

*Backward-Compatibility Aliases in `LifecoreTheme`:*
- `backgroundDark` / `deepVoidBackground` $\to$ `paperCanvas`
- `cardSurface` $\to$ `paperCard`
- `cardSurfaceSecondary` $\to$ `paperWell`
- `electricTeal` $\to$ `accentTeal`
- `athleticEmerald` / `recoveryGreen` $\to$ `statusOptimal`
- `amberWarning` / `strainOrange` $\to$ `statusWarning`
- `coralDanger` $\to$ `statusDanger`
- `recoveryPurple` $\to$ `accentIndigo`
- `textMuted` $\to$ `inkSecondary`
- `textSubtle` $\to$ `inkTertiary`

### 2.2. Hallmark Surface Ladder (`LifecoreGlassCardModifier` Replacement)
- **Card Rung (`lifecoreGlassCard`):**
  - Fill: `LifecoreTheme.paperCard` (`#FFFFFF`).
  - Stroke: `1.0pt` solid `borderColor ?? LifecoreTheme.ruleHairline`.
  - Corner Radius: `20pt` continuous.
  - Shadow: **None** (or ultra-subtle `Color.black.opacity(0.03), radius: 2, y: 1` when no custom border is active, strictly respecting Hallmark Gate F24).
- **Inner Grouping Rung (Zero Card-in-Card):**
  - Inside any `.lifecoreGlassCard(...)`, sub-items MUST use either:
    1. **Hairline Divider (`LifecoreHairlineDivider`)**: `Rectangle().fill(LifecoreTheme.ruleHairline).frame(height: 1)` separating rows or columns.
    2. **Tinted Well (`lifecoreWell`)**: `RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LifecoreTheme.paperWell)` with **zero border and zero shadow**.

### 2.3. Typography & Numeric Discipline
- All numeric metrics, paces, heart rates, weights, and deltas use `.font(.system(..., design: .rounded).monospacedDigit())`.
- All section headers, labels, and pills use sentence case (`"Сьогоднішня активність"`, `"Завтра"`, `"Через 2 дні"`).

---

## 3. Screen-by-Screen Redesign Architecture

### 3.1. App Shell (`LifecoreApp.swift` & `MainTabView.swift`)
- Switch `.preferredColorScheme(.dark)` to `.preferredColorScheme(.light)`.
- Set `TabView` `.tint(LifecoreTheme.accentPrimary)`.

### 3.2. `WorkoutsView.swift` & Upgraded Interactive 7-Day Calendar Strip (`RollingHorizonDeckView.swift`)
- **Interactive 7-Day Bevel Calendar Strip:**
  - Displays 7 days (`-3...3` relative to Today) inside a clean `paperCard` strip.
  - `@State private var selectedDayOffset: Int = 0` allows tapping any day (`-3` to `+3`).
  - Each day cell is a vertical capsule button (`minHeight: 76pt`, hit target $\ge 44\text{pt}$):
    - **Selected Day:** Background capsule filled with `LifecoreTheme.paperWell`, day number in `.bold` `inkPrimary`, and an active ring around the activity icon.
    - **Today Indicator:** Small `4pt` dot in `LifecoreTheme.accentPrimary` beneath the day label.
    - **Past Days (`offset < 0`):** Completed workout shows a solid `statusOptimal.opacity(0.15)` circle with `statusOptimal` activity glyph; rest day shows `paperWell` circle with `moon.zzz.fill` in `inkTertiary`.
    - **Future Days (`offset > 0`):** Queued stimulus shows dashed `accentTeal` circle with archetype glyph.
  - **Dynamic Selected-Day Context Panel:**
    - When `selectedDayOffset == 0` (Today): Displays the Today's Activity prescription card, segment pills, and the 1-tap Club/Custom Run button (`id: "btn_recalculate_club_queue"`).
    - When `selectedDayOffset < 0` (Past Day): Displays a summary of the completed `HKWorkout` on that date (or "День відновлення без записаних тренувань") plus a "Повернутись до сьогодні" button.
    - When `selectedDayOffset > 0` (Future Slot): Displays the preview of the queued `DailyWorkoutPrescription` for `horizonQueue[selectedDayOffset - 1]` plus a "Повернутись до сьогодні" button.
- **Upcoming Horizon Row:**
  - Replaced `ALL CAPS` slot labels (`"ЗАВТРА"`, `"ЧЕРЕЗ 2 ДНІ"`) with sentence-case labels (`"Завтра"`, `"Через 2 дні"`, `"Через 3 дні"`).
- **Workouts List & Detail (`WorkoutsView.swift`, `WorkoutDetailView.swift`, `WorkoutChartsView.swift`, `WorkoutDetailComponents.swift`, `CoachReportView.swift`):**
  - All dark literal backgrounds replaced with `LifecoreTheme.paperCanvas` and `LifecoreTheme.paperCard`.
  - Workout metrics arranged in a 4-column tabular stat row separated by vertical hairlines.
  - `SplitsTableView` & `IntervalLapsTableView`: Clean full-width tables with sentence-case headers, `ruleHairline` horizontal rules, and `.monospacedDigit()` cells.

### 3.3. `TodayView.swift`, `TacticalPrescriptionCard.swift` & `OvernightVitalsCard.swift`
- **Hero Bevel Rings Card (`ringsHeaderView`):**
  - 3 Bevel rings (`Відновлення`, `Навантаження`, `Калорії`) sit directly on the white `paperCard` canvas (removed inner `Color.white.opacity(0.03)` boxes).
  - Ring tracks use `ringColor.opacity(0.14)` on white paper with crisp `inkPrimary` center values.
  - Separated from ACWR, `AdaptiveEngineBadgeBar`, and `RPEQuickCalibrationRow` by `1px` `LifecoreTheme.ruleHairline` dividers.
- **Tactical Prescription Card (`TacticalPrescriptionCard.swift`):**
  - Sentence-case title `"Сьогоднішня активність"` instead of `"СЬОГОДНІШНЯ АКТИВНІСТЬ"`.
  - Preserves `id: "card_tactical_prescription"`, `id: "txt_prescription_archetype"`, and `id: "pill_prescription_reason"`.
- **Overnight Vitals Card (`OvernightVitalsCard.swift`):**
  - Eliminates card-in-card grid: renders `IllnessRadarBanner` as a top `paperWell` callout, followed by a clean 5-row vertical Apple Vitals ledger separated by `1px` `ruleHairline` dividers (`VitalsCorridorRow`).
  - Preserves `id: "card_overnight_vitals"` and `id: "card_body_battery"`.
- **Sleep & Metabolism Section (`TodayView.swift`):**
  - Replaces emoji prefixes (`✅`, `⚠️`) with SF Symbols (`checkmark.circle.fill`, `exclamationmark.triangle.fill`).

### 3.4. `NutritionView.swift`, `NutritionComponents.swift` & `FoodInputSheet.swift`
- Replaces all literal dark backgrounds and `.white` text with `LifecoreTheme` tokens.
- `MacroSummaryCard`: Clean white card with tabular macro progress bars and `ruleHairline` dividers.
- `FoodInputSheet`: Daylight form with `paperWell` text editor and preset chips (`id: "preset_oatmeal"`, `id: "input_food_text"`, `id: "btn_submit_food"`).

### 3.5. `TrendsView.swift`, `TrendsComponents.swift` & `CorrelationInsightsCard.swift`
- `TrendsRangePickerView` & `categorySwitcher`: Segmented controls styled with `paperWell` track and elevated `paperCard` active pill.
- `CorrelationInsightsCard`: Replaces nested bordered cards with a clean `ruleHairline`-divided list of correlation rows.
- `WeightTrendCard`, `AutonomicTrendCard`, `AerobicEfficiencyTrendCard`, `ACWRWorkloadTrendCard`: Light-mode Swift Charts with `ruleHairline` grid lines, `inkTertiary` axis labels, and SF Symbol badges instead of `💧` emojis.

---

## 4. Verification Matrix
1. **Compilation & Static Types:** `xcodebuild -project ios/Lifecore/Lifecore/Lifecore.xcodeproj -scheme Lifecore -destination 'generic/platform=iOS Simulator' build` passes with zero errors.
2. **Hallmark Token Audit:** Zero occurrences of `Color(red: 0.05`, `Color(red: 0.1`, or `.preferredColorScheme(.dark)` in `ios/Lifecore/`.
3. **Math Engine Verification:** All 12 deterministic suites in `MathEngineVerification.swift` pass.
4. **Maestro E2E Compatibility:** All 17 `.accessibilityIdentifier` hooks in `.maestro/01..05` remain intact and visible.
