# Lifecore v3.2 Design Spec: Deterministic Adaptive Training Prescription Engine (`TrainingPrescriptionEngine.swift`)

**Date:** 2026-10-23  
**Version:** Lifecore v3.2 (Phase 3.2)  
**Target Platform:** Native iOS (Swift 6, SwiftUI, SwiftData, HealthKit)  
**Execution Profile:** Atomic, strictly-typed 4-Phase roadmap engineered for zero-ambiguity execution by downstream Flash coding models.

---

## 1. Executive Summary & Core Athletic Goal

**Lifecore v3.2** introduces the **Deterministic Adaptive Training Prescription Engine (`TrainingPrescriptionEngine.swift`)**.
- **Core Athletic Goal:** Maximize **Aerobic Efficiency Factor ($EF = \text{Speed (m/min)} / \text{HR}$)** and running speed at lower heart rates while minimizing Cardiac Drift % within fixed workout time windows (45–75 min), rather than inflating junk mileage.
- **Architectural Discipline:**
  1. **100% Deterministic Swift 6 Math:** All inverse EWMA TRIMP budgeting, multi-gate physiological overrides, dynamic $EF_{75}$ pace derivation, rolling stimulus queue transitions, and pre-run carbohydrate prescriptions are computed natively in pure `Sendable` Swift structs.
  2. **Rolling 4-Archetype Stimulus Queue:** Replaces rigid calendar schedules with a self-adjusting 4-slot stimulus cycle (`aerobicBasePlusStrides` $\to$ `cruiseThresholdIntervals` $\to$ `recoveryFlush` $\to$ `progressiveQualityLongRun`) that preserves quality sessions when autonomic vitals or acute load spikes require temporary recovery insertion.
  3. **Seamless External Activity Reconciliation:** Automatically adapts the queue when the athlete logs an unplanned club run, calisthenics, or strength session.

---

## 2. Mathematical & Physiological Specifications

### 2.1. Inverse EWMA ACWR Load Budgeting
Given $\lambda_a = \frac{2}{7+1} = 0.25$ (7d Acute EWMA) and $\lambda_c = \frac{2}{28+1} \approx 0.0689655$ (28d Chronic EWMA), and target progressive overload ratio $R_{\text{target}} = \text{clamp}(r, 0.85, 1.25)$ (default `1.08`):
$$\text{TRIMP}_{\text{raw}} = \frac{R_{\text{target}} \cdot (1 - \lambda_c) \cdot L_{\text{chronic}}(t-1) - (1 - \lambda_a) \cdot L_{\text{acute}}(t-1)}{\lambda_a - R_{\text{target}} \cdot \lambda_c}$$
$$\text{TRIMP}_{\text{budget}} = \text{clamp}(\text{TRIMP}_{\text{raw}}, 0.0, 160.0)$$
* **Cold-Start & Spike Safeguards:**
  - If $L_{\text{chronic}}(t-1) < 25.0$, use `effectiveChronic = max(35.0, previousChronicLoad)` to avoid zero-budget lockouts for new users.
  - If yesterday's acute-to-chronic ratio $L_{\text{acute}}(t-1) / \max(20.0, L_{\text{chronic}}(t-1)) > 1.25$, cap $\text{TRIMP}_{\text{budget}} \le 45.0$ so quality sessions defer safely in favor of recovery.

### 2.2. Multi-Gate Physiological Override State Machine
Evaluates three sequential physiological gates to determine `multiplier`, `maxZone`, `durationScale`, and primary `AdaptationReason`:

1. **Gate 1 — Illness & Autonomic Vitals (`ImmuneSystemState` + `morningBodyBattery` + $Z_{\text{HRV}}$):**
   - `.illnessProdrome` $\implies$ `multiplier = 0.0`, `maxZone = .rest`, `reason = .blockedByIllnessProdrome`.
   - `.immuneWatch` OR `morningBodyBattery < 40` $\implies$ `multiplier = 0.55`, `maxZone = .zone2Easy`, `reason = .downgradedByVitalsOrBattery`.
   - `.trainingFatigue` (with $Z_{\text{HRV}} < -1.0$) $\implies$ `multiplier = 0.80`, `maxZone = .zone3Tempo`, `reason = .modulatedByHRV`.
   - `.optimal` $\implies$ `multiplier = 1.0`, `maxZone = .zone5VO2Max`, `reason = .optimalProgression`.
2. **Gate 2 — Caloric Deficit Protection (Nutrition Coupling):**
   - If rolling 3-day energy balance $\overline{\Delta E}_{3d} < -650.0\text{ kcal/day}$ AND `maxZone > .zone3Tempo`: cap `maxZone = .zone3Tempo`, `multiplier = min(multiplier, 0.85)`, `reason = .cappedByCaloricDeficit`.
3. **Gate 3 — Cardiac Drift Efficiency Gate (`WorkoutMathEngine`):**
   - Inspects up to last 3 aerobic runs ($\ge 45\text{ min}$):
   - If median $\text{Cardiac Drift} > 5.0\%$: `durationScale = 1.0` (locks duration expansion), `reason = .heldByCardiacDrift` (if Gate 1 & 2 are non-restrictive).
   - If median $\text{Cardiac Drift} \le 3.5\%$ AND $\Delta EF_{30d} > +1.5\%$: `durationScale = 1.08` (unlocks progression), `reason = .efficiencyUnlocked` (when Gate 1 & 2 allow).

### 2.3. Dynamic Pace & HR Zone Derivation from $EF_{75}$
From the 30-day rolling 75th percentile Efficiency Factor ($EF_{75}$, fallback `1.15 m/min/bpm`) and Heart Rate Reserve ($\text{HRR} = \text{HR}_{\text{max}} - \text{HR}_{\text{rest}}$, fallback `HR_rest = 55`, `HR_max = 192`):
- **Zone 1 (Recovery):** $\text{HR}_{\text{target}} = \text{HR}_{\text{rest}} + 0.62 \cdot \text{HRR}$; $\text{Speed} = EF_{75} \cdot \text{HR}_{\text{target}} \cdot 0.96$
- **Zone 2 (Aerobic Base):** $\text{HR}_{\text{target}} = \text{HR}_{\text{rest}} + 0.72 \cdot \text{HRR}$; $\text{Speed} = EF_{75} \cdot \text{HR}_{\text{target}}$
- **Zone 3 (Tempo):** $\text{HR}_{\text{target}} = \text{HR}_{\text{rest}} + 0.80 \cdot \text{HRR}$; $\text{Speed} = EF_{75} \cdot \text{HR}_{\text{target}} \cdot 1.02$
- **Zone 4 (Threshold):** $\text{HR}_{\text{target}} = \text{HR}_{\text{rest}} + 0.86 \cdot \text{HRR}$; $\text{Speed} = EF_{75} \cdot \text{HR}_{\text{target}} \cdot 1.05$
- **Zone 5 (VO2max):** $\text{HR}_{\text{target}} = \text{HR}_{\text{rest}} + 0.93 \cdot \text{HRR}$; $\text{Speed} = EF_{75} \cdot \text{HR}_{\text{target}} \cdot 1.12$
- **Pace Conversion:** $\text{Pace (sec/km)} = \text{round}(60000.0 / \max(80.0, \text{Speed}))$.

### 2.4. Polarized 4-Archetype Rolling Queue & Fueling Prescription
- **Cycle:** `[.aerobicBasePlusStrides, .cruiseThresholdIntervals, .recoveryFlush, .progressiveQualityLongRun]`.
- **Non-Destructive Deferral:** When $\text{TRIMP}_{\text{final}} = \text{TRIMP}_{\text{budget}} \cdot \text{multiplier}$ or `maxZone` is insufficient for a queued quality session (`.cruiseThresholdIntervals` requires $\text{TRIMP}_{\text{final}} \ge 68$ and `maxZone >= .zone4Threshold`; `.progressiveQualityLongRun` requires $\text{TRIMP}_{\text{final}} \ge 72$ and `maxZone >= .zone3Tempo`), the quality session remains at the head of the queue for tomorrow while today executes `.recoveryFlush` (or `.rest` if `maxZone == .rest`).
- **Pre-Workout Carbohydrate Formula (for $\text{TRIMP}_{\text{final}} \ge 75$):**
  $$\text{Carbs}_{g} = \text{roundToNearest5}\left(\text{clamp}\left( \frac{\text{TRIMP}_{\text{final}}}{1.8} \cdot \left(1.0 + |\beta_{\text{Carbs}\to\text{Drift}}| \cdot 0.10\right), 25.0, 110.0 \right)\right)$$
  *(Note: Handles both decimal slope representation e.g. `-0.018` where $\times 10 \to 0.18$ and percentage-point slope representation e.g. `-1.8` normalized to $|\beta|/10$ so the multiplier stays physiologically bounded in $[1.05, 1.45]$).*

---

## 3. Target Files & Verification Matrix

1. `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/TrainingPrescriptionEngine.swift` (NEW)
2. `ios/Lifecore/Lifecore/Lifecore/Core/Storage/TrainingPlanModels.swift` (NEW — SwiftData `@Model final class AthleteTrainingPlanState` + `TrainingPlanStorageService`)
3. `ios/Lifecore/Lifecore/Lifecore/Core/Storage/SwiftDataModels.swift` (UPDATE — register `AthleteTrainingPlanState.self` in `LifecoreDataStore`)
4. `ios/Lifecore/Lifecore/Lifecore/Features/Today/TacticalPrescriptionCard.swift` (NEW — Liquid Glass Bento prescription widget)
5. `ios/Lifecore/Lifecore/Lifecore/Features/Workouts/RollingHorizonDeckView.swift` (NEW — 3-session horizon deck + 1-tap Club/Custom Run override)
6. `ios/Lifecore/Lifecore/Lifecore/Features/Today/TodayView.swift` & `WorkoutsView.swift` (UPDATE — wire UI cards)
7. `ios/Lifecore/Lifecore/Lifecore/Core/AI/CoachPrompt.swift` (UPDATE — optional tactical briefing verbalizer)
8. `ios/Lifecore/Lifecore/Lifecore/Core/MathEngine/MathEngineVerification.swift` (UPDATE — Suite 12: `verifyTrainingPrescriptionEngine()`)
9. `.maestro/05_training_prescription_flow.yaml` & `.maestro/suite.yaml` (NEW / UPDATE — E2E verification)
