# Lifecore v3.4 Design Spec: Hierarchical Health RAG & Multi-Layered Conversational Analyst (`LifecoreIntelligenceEngine`)

**Date:** 2026-10-28  
**Version:** Lifecore v3.4 (Phase 3.4)  
**Target Platform:** Native iOS (Swift 6, SwiftUI, SwiftData, HealthKit)  
**Execution Profile:** Atomic 4-Phase roadmap engineered for zero-ambiguity execution.

---

## 1. Executive Summary & Architectural Problem Statement

The legacy single-shot workout coach in `CoachReportView.swift` and `CoachPrompt.swift` suffered from four structural defects:
1. **Broken UI Rendering:** Raw `###` Markdown headings and emojis were rendered inside `Text(LocalizedStringKey(...))`, which only parses inline Markdown in SwiftUI, violating the Phase 3.3 Hallmark v2.0.0 Daylight design system (`LifecoreDesignSystem.swift`).
2. **Prompt Example Parroting:** Hardcoded example sentences in `CoachPrompt.systemPrompt` caused Gemini to echo boilerplate cliches rather than analyzing actual split telemetry.
3. **Effort-Zone Blindness in Benchmarks:** `WorkoutMathEngine.computeHistoricalBenchmark` matched workouts solely by distance ($\pm 20\%$), misinterpreting a $+27\text{ bpm}$ heart rate increase (Zone 4 threshold vs Zone 2 easy run) as "improved endurance" rather than an intensity-zone shift (`higherIntensityEffort`).
4. **Siloed Telemetry:** The AI coach operated without access to 48h nutrition intake (`MealStorageService`), learned personal $\beta$-sensitivities (`AdaptivePhysiologyEngine`), active tactical prescriptions (`TrainingPrescriptionEngine`), or persistent athlete episodic memory, and offered no multi-turn conversational drill-down.

**Lifecore v3.4** replaces this siloed text generator with a **Bevel Intelligence-grade 4-Layer Hierarchical Health RAG & Multi-Layered Conversational Analyst**:
- **Layer 1 — Deterministic Effort-Aware Telemetry & Benchmark Math (`WorkoutMathEngine.swift`):** Classifies historical comparisons into `trueAerobicGain`, `higherIntensityEffort`, `easyRecoveryEffort`, or `cardiacStrainDecoupling` based on coupled $(\Delta\text{Pace}, \Delta\text{HR}, \Delta EF)$ vectors.
- **Layer 2 — On-Device 3-Tier Health Context Graph & Hybrid RAG (`LifecoreContextRAG.swift` + SwiftData):**
  - **Tier L1 (Acute 48h Slice):** Split-by-split telemetry, 48h logged meals (kcal, carbs, sodium, late-meal timing, whole-food ratio), overnight 5-metric Vitals (`ImmuneSystemState`), and Body Battery.
  - **Tier L2 (Mesocycle 30d Dossier):** EWMA ACWR, $EF_{75}$, learned $\beta$-sensitivities ($\beta_{\text{Carbs}\to\text{Drift}}$, $\beta_{\text{LateMeal}\to\text{RHR}}$, $\beta_{\text{Na}\to\text{H2O}}$), and active rolling queue state from `TrainingPrescriptionEngine`.
  - **Tier L3 (Episodic Semantic Memory):** Persistent `AthleteMemoryEntity` storing athlete notes, musculoskeletal feedback, race goals, and distilled insights scored via deterministic Hybrid BM25/Tag/Recency retrieval.
- **Layer 3 — Structured JSON Coach Debrief (`StructuredWorkoutDebrief`):** Eliminates raw Markdown `###` and emojis. Gemini outputs a strictly typed JSON schema rendered via native Hallmark Daylight surfaces (`paperCard`, `paperWell`, `ruleHairline`, SF Symbols, `.monospacedDigit()`).
- **Layer 4 — Multi-Layered Conversational Analyst (`LifecoreIntelligenceChatView.swift`):** Interactive Bevel-style multi-turn chat sheet accessible from any workout (`WorkoutDetailView`) and from the `TodayView` cockpit. Supports evidence metric pills, follow-up suggestion chips, and automatic extraction of new athlete facts (`extractedMemoryFact`) into SwiftData `AthleteMemoryEntity`.

---

## 2. Deterministic Math & RAG Scoring Specifications

### 2.1. Effort-Normalized Benchmark Classification (`BenchmarkRegime`)
Given `paceDeltaSecPerKm` ($\Delta P$, negative = faster), `hrDeltaBpm` ($\Delta\text{HR}$), and `efDelta` ($\Delta EF$):
1. **`higherIntensityEffort`:** $\Delta\text{HR} \ge +10.0\text{ bpm}$ AND $\Delta P < -10.0\text{ sec/km}$.
   - *Sub-evaluation:* If $\Delta EF \ge 0.0$, biomechanics and stroke volume scaled efficiently into the higher zone; if $\Delta EF < -0.02$, the pace increase came at disproportionate cardiovascular cost.
2. **`easyRecoveryEffort`:** $\Delta\text{HR} \le -10.0\text{ bpm}$ AND $\Delta P > +10.0\text{ sec/km}$.
   - Controlled lower-zone aerobic session; slower pace is intentional zone discipline, not fitness loss.
3. **`trueAerobicGain`:** $|\Delta\text{HR}| < 10.0\text{ bpm}$ AND ($\Delta EF \ge +0.015$ OR ($\Delta P \le -5.0\text{ sec/km}$ AND $\Delta\text{HR} \le +3.0\text{ bpm}$)).
   - Genuine physiological progression at comparable cardiac cost.
4. **`cardiacStrainDecoupling`:** $\Delta EF \le -0.020$ AND ($\Delta\text{HR} \ge +5.0\text{ bpm}$ OR $\Delta P \ge +8.0\text{ sec/km}$).
   - Elevated internal cost for the pace (heat, glycogen depletion, dehydration, or cumulative fatigue).
5. **`steadyBaseline`:** All other cases within normal day-to-day biological variance ($|\Delta EF| < 0.015$, $|\Delta\text{HR}| < 10.0\text{ bpm}$).

### 2.2. On-Device Hybrid RAG Scoring Formula (`LifecoreContextRAG`)
For a user query $Q$ (tokenized into normalized stems $T_Q$) and context tags $C_Q$ (e.g., `["running", "hr_drift", "carbs", "sleep"]`), each stored `AthleteMemoryEntity` node $m$ at age $\Delta t_{\text{days}}$ is scored deterministically:
$$\text{Score}(m, Q) = 0.45 \cdot S_{\text{BM25}}(m, T_Q) + 0.35 \cdot S_{\text{tags}}(m, C_Q) + 0.20 \cdot e^{-\lambda \cdot \Delta t_{\text{days}}}$$
where:
- $S_{\text{BM25}}(m, T_Q) \in [0, 1]$ is normalized term-overlap saturation ($k_1 = 1.2, b = 0.75$).
- $S_{\text{tags}}(m, C_Q) = \frac{|Tags_m \cap C_Q|}{\max(1, |C_Q|)}$.
- $\lambda = \frac{\ln 2}{21.0} \approx 0.033$ (21-day half-life for acute physiological notes; `pinnedGoal` nodes use $\lambda = 0$).

---

## 3. Data Contracts & Schema Definitions

### 3.1. Structured Workout Debrief Schema (`StructuredWorkoutDebrief`)
```swift
public struct StructuredWorkoutDebrief: Codable, Sendable, Equatable {
    public struct MetricEvidencePill: Codable, Sendable, Equatable, Identifiable {
        public var id: String { "\(labelUk):\(valueUk)" }
        public let labelUk: String
        public let valueUk: String
        public let tone: String // "optimal", "warning", "danger", "neutral"
    }

    public let headlineUk: String
    public let regimeBadgeUk: String
    public let regimeTone: String // "optimal", "teal", "warning", "danger"
    public let executionAnalysisUk: String      // 70%: Split-specific pacing, elevation & cardiac drift
    public let benchmarkComparisonUk: String    // 15%: Effort-normalized delta explanation
    public let rootCauseAndDirectiveUk: String  // 15%: 48h nutrition/sleep causal link + 24h prescription
    public let evidencePills: [MetricEvidencePill]
    public let followUpQuestionsUk: [String]
}
```

### 3.2. Multi-Layered Chat Analyst Response Schema (`AnalystChatTurnResponse`)
```swift
public struct AnalystChatTurnResponse: Codable, Sendable, Equatable {
    public let answerHeadlineUk: String
    public let answerBodyUk: String
    public let citedMetrics: [StructuredWorkoutDebrief.MetricEvidencePill]
    public let actionableTakeawayUk: String?
    public let suggestedFollowUpsUk: [String]
    public let extractedMemoryFactUk: String?
    public let extractedMemoryCategory: String? // "goal", "injury_note", "nutrition_habit", "workout_feel"
}
```

---

## 4. Target Files & Verification Matrix

1. `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/WorkoutMathEngine.swift` (MODIFY — Add `BenchmarkRegime` classification & effort-normalized narrative to `BenchmarkDelta`)
2. `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SwiftDataModels.swift` (MODIFY — Add `AthleteMemoryEntity`, `ChatMessageEntity`, and `AthleteMemoryStorageService`)
3. `ios/Lifecore/Lifecore/Lifecore/Core/AI/LifecoreContextRAG.swift` (NEW — 3-tier L1/L2/L3 Context Assembler & Hybrid BM25/Tag/Recency Retriever)
4. `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift` (MODIFY — Replace template-polluted Markdown prompt with `StructuredWorkoutDebrief` & `AnalystChatTurnResponse` JSON schemas and multi-layer RAG prompt builders)
5. `ios/Lifecore/Lifecore/Lifecore/Core/AI/GeminiService.swift` (MODIFY — Add `generateStructuredCoachDebrief` and `sendAnalystChatMessage` with deterministic offline fallbacks)
6. `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/CoachReportView.swift` (MODIFY — Native Hallmark Daylight structured cards, zero `###` or emojis, evidence pills, and 1-tap follow-up launcher into `LifecoreIntelligenceChatView`)
7. `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/LifecoreIntelligenceChatView.swift` (NEW — Multi-layered Bevel-style conversational analyst sheet with RAG dossier badge, cited metric pills, memory extraction indicator, and quick chips)
8. `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/WorkoutDetailView.swift` & `Features/Today/TodayView.swift` (MODIFY — Wire 48h nutrition + adaptive + prescription context into `CoachReportView` and add `Lifecore Intelligence` entry point on `TodayView`)
9. `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift` (MODIFY — Add Verification Suite 13: `verifyLifecoreIntelligenceAndRAG()`)

