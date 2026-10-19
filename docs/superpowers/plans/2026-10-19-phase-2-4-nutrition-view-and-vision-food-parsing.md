# Phase 2.4: Nutrition View, Vision Food Parsing & Optimistic UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS nutrition logging experience with vision/text food parsing, +12.5% caloric deficit buffer, 04:00 AM dietary day shift, quality taxonomy tagging, optimistic UI updates (<0.2s), HealthKit dietary write-back, and Gemini model cascading.

**Architecture:** Native iOS (SwiftUI, HealthKit, SwiftData/Local Storage) coupled with Google AI Studio Gemini REST API supporting multimodal vision and structured JSON decoding.

**Tech Stack:** Swift 6, SwiftUI, HealthKit, PhotosUI, Google AI Studio Gemini API (`gemini-3.8-flash` -> `gemini-2.5-flash` -> `gemini-3.6-flash`).

**Spec:** [docs/ROADMAP.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/ROADMAP.md) (Phase 2, Step 2.4), [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md) (Section 5.1 & Section 2.5), [utils/prompt.js](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/utils/prompt.js), [utils/dateUtils.js](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/utils/dateUtils.js).

## Global Constraints
- **Token Economy:** All documentation, code, variable names, and comments strictly in concise English.
- **Ukrainian Output:** Meal names, quality descriptions, and advice strictly in Ukrainian.
- **Deficit Buffer (+12.5%):** Strictly compute `kcal_final = round(kcal_exact * 1.125)`. Protein, fat, carbs remain exact.
- **Cooked Weight:** Always estimate grains, pasta, buckwheat, oats, and meat based on cooked state.
- **Quality Tags:** Mandatory 2-4 tags from `whole_food`, `ultra_processed`, `solid`, `liquid`, `fast_absorbing`, `slow_absorbing`, `high_sodium`.
- **04:00 AM Cutoff:** Meals logged between 00:00 and 03:59 belong to previous day's `dietary_date`.
- **Model Cascade:** `gemini-3.8-flash` -> `gemini-2.5-flash` -> `gemini-3.6-flash`.

---

### Task 1: Food Prompt & Domain Models (`Core/AI/FoodPrompt.swift`)
- Create `Core/AI/FoodPrompt.swift` containing:
  - Strict English system prompt matching `utils/prompt.js`.
  - Type-safe Swift models: `MealNutrition`, `Micronutrients`, `AminoAcids`, `MealRecord`.
  - Dietary date calculation helper: `FoodPrompt.dietaryDate(for:offsetDays:)` enforcing the 04:00 AM day shift.

### Task 2: Multimodal Gemini Service & Model Cascade (`Core/AI/GeminiService.swift`)
- Upgrade `GeminiService.swift`:
  - Add image Base64 inline data payload support for multimodal vision.
  - Implement cascading across `["gemini-3.8-flash", "gemini-2.5-flash", "gemini-3.6-flash"]`.
  - Add `analyzeFood(imageJpegData:textDescription:) async throws -> MealNutrition`.
  - Provide realistic offline simulation for development and testing.

### Task 3: HealthKit Dietary Write-Back (`Core/HealthKit/HealthKitManager.swift`)
- Expand `HealthKitManager.swift`:
  - Request write and read authorization for dietary energy, protein, fat, carbohydrates, and sodium.
  - Add `saveMealToHealthKit(meal:date:) async throws` writing `HKQuantitySample`s to Apple Health.

### Task 4: Local Meal Persistence Service (`Core/Storage/MealStorageService.swift`)
- Implement `MealStorageService.swift` providing local persistent storage for meals, grouped by `dietary_date`, with support for optimistic insertion, completion update, and deletion.

### Task 5: Nutrition UI Components & Input Flow (`Features/Nutrition/`)
- Create `Features/Nutrition/NutritionComponents.swift`:
  - `MacroSummaryCard`: Calorie bar with +12.5% buffer indicator, macro breakdown (P/F/C).
  - `DietaryQualityCard`: Whole food vs ultra-processed ratio bar, sodium retention warning, and leucine MPS threshold.
  - `MealItemCard`: Displays analyzed meals with macro tags, micronutrients popup, and delete action.
  - `OptimisticAnalyzingCard`: Shimmer card showing instant <0.2s pending state.
- Create `Features/Nutrition/FoodInputSheet.swift`:
  - Integrated PhotosPicker camera/library + text description field (<5s flow).

### Task 6: Assemble Full Nutrition View (`Features/Nutrition/NutritionView.swift`)
- Replace placeholder `Features/Nutrition/NutritionView.swift`:
  - Dietary date switcher (Today, Yesterday, previous days with 04:00 AM cutoff).
  - "Log for Yesterday" fast toggle.
  - Macro summary and quality cards.
  - Chronological meal list with optimistic cards.
  - HealthKit automatic background write-back.

### Task 7: Build Verification, Documentation & Git Commit
- Run `xcodebuild` ensuring 0 compilation errors.
- Update `docs/ROADMAP.md` and `CHANGELOG.md`.
- Commit and push to `origin/main`.
