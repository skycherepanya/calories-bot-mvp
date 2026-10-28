# Lifecore v3.4: Hierarchical Health RAG & Multi-Layered Conversational Analyst Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy single-shot Markdown workout coach with a 4-layer Hierarchical Health RAG engine (`LifecoreContextRAG`), effort-normalized benchmark math (`BenchmarkRegime`), structured Hallmark Daylight debrief cards (`StructuredWorkoutDebrief`), and a Bevel-style multi-layered conversational analyst (`LifecoreIntelligenceChatView`).

**Architecture:** Deterministic Swift 6 math engines (`WorkoutMathEngine`, `LifecoreContextRAG`) assemble a 3-tier physiological dossier (L1 48h acute splits/meals/vitals, L2 30d adaptive $\beta$-sensitivities/ACWR/prescriptions, L3 hybrid BM25/tag/recency episodic memory from SwiftData) in <15ms on-device. `GeminiService` consumes this structured dossier and returns strictly typed JSON (`StructuredWorkoutDebrief` and `AnalystChatTurnResponse`) rendered natively in Hallmark v2.0.0 Daylight surfaces without raw Markdown `###` or emojis, while automatically persisting newly discovered athlete facts back into `AthleteMemoryEntity`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, HealthKit, Gemini JSON Mode (`response_mime_type: "application/json"`), Hallmark v2.0.0 Daylight Design System (`LifecoreDesignSystem.swift`).

**Spec:** [`docs/superpowers/specs/2026-10-28-lifecore-v3-4-multilayer-rag-and-chat-analyst-design.md`](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/superpowers/specs/2026-10-28-lifecore-v3-4-multilayer-rag-and-chat-analyst-design.md)

## Global Constraints

- **Xcode Synchronized Root Group:** `ios/Lifecore/Lifecore/Lifecore` automatically compiles all `.swift` files in its directory tree without modifying `project.pbxproj`.
- **Strict Separation of Math vs AI:** All benchmark regime classifications, 48h macro aggregations, and BM25/tag/recency RAG scores MUST be computed deterministically in Swift 6 (`Sendable` types).
- **Hallmark v2.0.0 Daylight Discipline:** Use `LifecoreTheme.paperCanvas`, `paperCard`, `paperWell`, `ruleHairline`, SF Symbols (zero emoji headers or raw `###` Markdown), and `.monospacedDigit()` for all numeric values.
- **Language Protocol:** Code, comments, and prompt instructions in concise English; all user-facing strings, fallback narratives, and AI outputs in Ukrainian.

---

### Task 1: Effort-Normalized Benchmark Math (`WorkoutMathEngine.swift`) & Verification Suite 13 Foundation

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/WorkoutMathEngine.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`

**Interfaces:**
- Produces:
  - `public enum BenchmarkRegime: String, Codable, Sendable, Equatable` (`.trueAerobicGain`, `.higherIntensityEffort`, `.easyRecoveryEffort`, `.cardiacStrainDecoupling`, `.steadyBaseline`)
  - `BenchmarkDelta.regime: BenchmarkRegime` and `BenchmarkDelta.regimeBadgeUk: String`
  - `WorkoutMathEngine.classifyBenchmarkRegime(paceDeltaSecPerKm: Double, hrDeltaBpm: Double, efDelta: Double) -> BenchmarkRegime`

- [ ] **Step 1: Add `BenchmarkRegime` and effort-normalized narrative to `WorkoutMathEngine.swift`**

Update `BenchmarkDelta` and `computeHistoricalBenchmark` in `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/WorkoutMathEngine.swift`:

```swift
public enum BenchmarkRegime: String, Codable, Sendable, Equatable {
    case trueAerobicGain = "true_aerobic_gain"
    case higherIntensityEffort = "higher_intensity_effort"
    case easyRecoveryEffort = "easy_recovery_effort"
    case cardiacStrainDecoupling = "cardiac_strain_decoupling"
    case steadyBaseline = "steady_baseline"

    public var badgeTitleUk: String {
        switch self {
        case .trueAerobicGain: return "Чистий аеробний прогрес"
        case .higherIntensityEffort: return "Вища зона інтенсивності"
        case .easyRecoveryEffort: return "Контрольований легкий режим"
        case .cardiacStrainDecoupling: return "Підвищена ціна темпу"
        case .steadyBaseline: return "Стабільна базова форма"
        }
    }
}
```

In `BenchmarkDelta`, add `public let regime: BenchmarkRegime` (with default `.steadyBaseline` in `init` for backward compatibility) and implement `WorkoutMathEngine.classifyBenchmarkRegime`:

```swift
    public static func classifyBenchmarkRegime(
        paceDeltaSecPerKm: Double,
        hrDeltaBpm: Double,
        efDelta: Double
    ) -> BenchmarkRegime {
        if hrDeltaBpm >= 10.0 && paceDeltaSecPerKm < -10.0 {
            return .higherIntensityEffort
        }
        if hrDeltaBpm <= -10.0 && paceDeltaSecPerKm > 10.0 {
            return .easyRecoveryEffort
        }
        if abs(hrDeltaBpm) < 10.0 && (efDelta >= 0.015 || (paceDeltaSecPerKm <= -5.0 && hrDeltaBpm <= 3.0)) {
            return .trueAerobicGain
        }
        if efDelta <= -0.020 && (hrDeltaBpm >= 5.0 || paceDeltaSecPerKm >= 8.0) {
            return .cardiacStrainDecoupling
        }
        return .steadyBaseline
    }
```

Update `computeHistoricalBenchmark` in `WorkoutMathEngine.swift` so `summary` accurately reflects `regime`:
- When `regime == .higherIntensityEffort`: explain that the faster pace (`-89.7 с/км`) was achieved by working in a higher heart rate zone (`+27 уд/хв`), noting whether `efDelta >= 0` preserved biomechanical efficiency.
- When `regime == .trueAerobicGain`: highlight true fitness gain (faster pace at equal/lower HR).

---

### Task 2: SwiftData Memory & Chat Persistence (`SwiftDataModels.swift`) + 3-Tier Hybrid RAG Engine (`LifecoreContextRAG.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SwiftDataModels.swift`
- Create: `ios/Lifecore/Lifecore/Lifecore/Core/AI/LifecoreContextRAG.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift`

**Interfaces:**
- Produces:
  - `@Model public final class AthleteMemoryEntity` (stores `id`, `factTextUk`, `category`, `tags`, `createdAt`, `isPinnedGoal`, `sourceContext`)
  - `@MainActor public enum AthleteMemoryStorageService` (`saveFact(...)`, `fetchAllFacts()`, `deleteFact(id:)`, `seedDefaultMemoriesIfNeeded()`)
  - `public struct AssembledHealthDossier: Codable, Sendable, Equatable` (contains L1 `AcuteNutritionAndVitalsSlice`, L2 `MesocycleAdaptiveSlice`, L3 `[RetrievedMemoryNode]`)
  - `public enum LifecoreContextRAG` (`scoreMemoryNode(...)`, `retrieveTopMemories(...)`, `assembleDossier(...)`)

- [ ] **Step 1: Add `AthleteMemoryEntity` and `AthleteMemoryStorageService` to `SwiftDataModels.swift`**

Register `AthleteMemoryEntity.self` in `LifecoreDataStore.shared` schema and implement `AthleteMemoryStorageService` in `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SwiftDataModels.swift`:

```swift
// MARK: - AthleteMemoryEntity (Episodic & Semantic RAG Memory Node)

@Model
public final class AthleteMemoryEntity {
    @Attribute(.unique) public var id: UUID
    public var factTextUk: String
    public var category: String         // "goal", "injury_note", "nutrition_habit", "workout_feel", "coach_insight"
    public var tags: [String]
    public var isPinnedGoal: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        factTextUk: String,
        category: String,
        tags: [String] = [],
        isPinnedGoal: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.factTextUk = factTextUk
        self.category = category
        self.tags = tags
        self.isPinnedGoal = isPinnedGoal
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 2: Create `ios/Lifecore/Lifecore/Lifecore/Core/AI/LifecoreContextRAG.swift`**

Implement the deterministic 3-tier RAG engine (`L1 Acute 48h Nutrition + Vitals + Workout`, `L2 30d Mesocycle + Adaptive Sensitivities + Tactical Prescription`, `L3 Episodic Hybrid BM25/Tag/Recency Memory`):

```swift
import Foundation

public struct RetrievedMemoryNode: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let factTextUk: String
    public let category: String
    public let tags: [String]
    public let relevanceScore: Double
    public let ageDays: Int

    public init(
        id: UUID = UUID(),
        factTextUk: String,
        category: String,
        tags: [String],
        relevanceScore: Double,
        ageDays: Int
    ) {
        self.id = id
        self.factTextUk = factTextUk
        self.category = category
        self.tags = tags
        self.relevanceScore = relevanceScore
        self.ageDays = ageDays
    }
}

public struct AcuteNutritionSlice: Codable, Sendable, Equatable {
    public let last24hKcal: Double
    public let last24hCarbsG: Double
    public let last24hProteinG: Double
    public let last24hSodiumMg: Double
    public let wholeFoodRatioPct: Int
    public let hadLateMealAfter2130: Bool
    public let recentMealNames: [String]

    public init(
        last24hKcal: Double = 0,
        last24hCarbsG: Double = 0,
        last24hProteinG: Double = 0,
        last24hSodiumMg: Double = 0,
        wholeFoodRatioPct: Int = 85,
        hadLateMealAfter2130: Bool = false,
        recentMealNames: [String] = []
    ) {
        self.last24hKcal = last24hKcal
        self.last24hCarbsG = last24hCarbsG
        self.last24hProteinG = last24hProteinG
        self.last24hSodiumMg = last24hSodiumMg
        self.wholeFoodRatioPct = wholeFoodRatioPct
        self.hadLateMealAfter2130 = hadLateMealAfter2130
        self.recentMealNames = recentMealNames
    }
}

public struct AssembledHealthDossier: Codable, Sendable, Equatable {
    public let workoutAnalysis: WorkoutAnalysisResult?
    public let recoveryContext: RecentRecoveryContext?
    public let acuteNutrition: AcuteNutritionSlice
    public let adaptiveSensitivitiesSummaryUk: String
    public let next24hPrescriptionSummaryUk: String
    public let retrievedMemories: [RetrievedMemoryNode]

    public init(
        workoutAnalysis: WorkoutAnalysisResult? = nil,
        recoveryContext: RecentRecoveryContext? = nil,
        acuteNutrition: AcuteNutritionSlice = .init(),
        adaptiveSensitivitiesSummaryUk: String = "",
        next24hPrescriptionSummaryUk: String = "",
        retrievedMemories: [RetrievedMemoryNode] = []
    ) {
        self.workoutAnalysis = workoutAnalysis
        self.recoveryContext = recoveryContext
        self.acuteNutrition = acuteNutrition
        self.adaptiveSensitivitiesSummaryUk = adaptiveSensitivitiesSummaryUk
        self.next24hPrescriptionSummaryUk = next24hPrescriptionSummaryUk
        self.retrievedMemories = retrievedMemories
    }
}
```

Include deterministic tokenization, `scoreMemoryNode(factText:tags:isPinnedGoal:ageDays:queryTokens:contextTags:) -> Double`, `retrieveTopMemories(...)`, and `extractCandidateMemoryFact(fromUserMessage:)` so user statements in chat (e.g., about pain/discomfort, race goals, weather, shoes, or club runs) are deterministically captured even offline.

- [ ] **Step 3: Add Suite 13 (`verifyLifecoreIntelligenceAndRAG()`) to `MathEngineVerification.swift`**

Verify:
1. `Case 13.1 (Effort-Normalized Benchmark Regime):` `-89.7 sec/km` with `+27.0 bpm` and `+0.044 EF` is classified strictly as `.higherIntensityEffort` (never misclassified as low-effort aerobic gain), while `-12.0 sec/km` with `-1.5 bpm` and `+0.035 EF` is classified as `.trueAerobicGain`.
2. `Case 13.2 (Hybrid RAG Retrieval Ranking):` Given 5 memory nodes, a query about cardiac drift and pre-run carbs ranks the carbohydrate/glycogen memory node #1 over unrelated shoe or sodium notes.
3. `Case 13.3 (Structured Debrief Offline Fallback & Zero Raw Markdown):` `GeminiService.shared.generateStructuredWorkoutDebriefOffline(...)` produces valid `StructuredWorkoutDebrief` with zero `###` substrings, non-empty `evidencePills`, and 3 contextual `followUpQuestionsUk`.

---

### Task 3: Structured JSON Schemas & Multi-Layer Prompt Engine (`CoachPrompt.swift` & `GeminiService.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Core/AI/GeminiService.swift`

**Interfaces:**
- Produces:
  - `public struct StructuredWorkoutDebrief: Codable, Sendable, Equatable`
  - `public struct AnalystChatTurnResponse: Codable, Sendable, Equatable`
  - `public struct AnalystChatMessage: Identifiable, Codable, Sendable, Equatable`
  - `CoachPrompt.structuredDebriefSystemPrompt: String` (strictly forbids prompt-example parroting and enforces `StructuredWorkoutDebrief` JSON output)
  - `CoachPrompt.analystChatSystemPrompt: String` (enforces `AnalystChatTurnResponse` JSON output with multi-layered L1/L2/L3 causal synthesis)
  - `CoachPrompt.buildDossierPrompt(dossier: AssembledHealthDossier) -> String`
  - `GeminiService.generateStructuredCoachDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief`
  - `GeminiService.sendAnalystChatMessage(userQuery: String, history: [AnalystChatMessage], dossier: AssembledHealthDossier) async throws -> AnalystChatTurnResponse`

- [ ] **Step 1: Upgrade `CoachPrompt.swift` with `StructuredWorkoutDebrief`, `AnalystChatTurnResponse`, and RAG Dossier Builder**

Remove all copy-pasteable example sentences from `CoachPrompt.swift`. Define `StructuredWorkoutDebrief` and `AnalystChatTurnResponse` and build the 3-tier RAG prompt payload (`L1 WORKOUT & 48H NUTRITION`, `L2 ADAPTIVE PHYSIOLOGY & PRESCRIPTION`, `L3 EPISODIC ATHLETE MEMORY`).

- [ ] **Step 2: Upgrade `GeminiService.swift` with JSON-Mode Debrief & Multi-Turn Analyst Chat**

Add `generateStructuredCoachDebrief(dossier:)` and `sendAnalystChatMessage(userQuery:history:dossier:)` using `responseMimeType: "application/json"`, cascading across `Self.foodModelCascade`, and falling back to high-precision deterministic synthesis (`generateStructuredWorkoutDebriefOffline` and `generateOfflineAnalystChatResponse`) that inspects exact split numbers, `BenchmarkRegime`, 24h carbs/sodium, and `RecentRecoveryContext`.

---

### Task 4: Hallmark Daylight Structured Coach Card (`CoachReportView.swift`) & Multi-Layered Chat Analyst UI (`LifecoreIntelligenceChatView.swift`)

**Files:**
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/CoachReportView.swift`
- Create: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/LifecoreIntelligenceChatView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutDetailView.swift`
- Modify: `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift`

**Interfaces:**
- Consumes: `AssembledHealthDossier`, `StructuredWorkoutDebrief`, `AnalystChatTurnResponse`, `LifecoreContextRAG`, `AthleteMemoryStorageService`
- Produces:
  - Redesigned `CoachReportView` rendering:
    1. Top header with `Lifecore Intelligence` badge and active RAG context pill (`3 рівні контексту • Спліти • Їжа • Vitals`).
    2. Verdict Headline + `BenchmarkRegime` status pill.
    3. Evidence Metric Pills strip (`.lifecoreWell()` pills with `.monospacedDigit()`).
    4. Three native Hallmark Daylight sections (`Виконання та розкладка (70%)`, `Динаміка форми та інтенсивність (15%)`, `Фізіологічні причини та план на 24 год (15%)`) separated by `LifecoreHairlineDivider()`.
    5. Interactive follow-up question chips + primary CTA button **`Запитати Lifecore Intelligence`** that opens `LifecoreIntelligenceChatView` pre-seeded with the full workout + nutrition + vitals RAG dossier.
  - New `LifecoreIntelligenceChatView` sheet:
    1. Active RAG Dossier header showing live connected sources (`Тренування`, `Харчування 48г`, `Нічні Vitals`, `Пам'ять: N фактів`).
    2. Expandable Memory Bank drawer allowing the user to inspect or delete learned athlete facts (`AthleteMemoryEntity`).
    3. Multi-turn message feed where assistant responses render structured cards (`answerHeadlineUk`, cited metric pills, `answerBodyUk`, highlighted `actionableTakeawayUk`, and a badge when a new memory fact is saved).
    4. Tappable contextual follow-up chips and bottom message composer.

- [ ] **Step 1: Create `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/LifecoreIntelligenceChatView.swift`**
- [ ] **Step 2: Rewrite `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/CoachReportView.swift` to render `StructuredWorkoutDebrief` and launch `LifecoreIntelligenceChatView`**
- [ ] **Step 3: Wire full 3-tier RAG Dossier in `WorkoutDetailView.swift` and add a `Lifecore Intelligence` launcher button in `TodayView.swift`**
- [ ] **Step 4: Run `xcodebuild` verification and update project documentation (`CHANGELOG.md`, `PROJECT_KNOWLEDGE.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `README.md`)**

