import Foundation

// MARK: - Prescription Unavailability & Outcome

public enum PrescriptionUnavailabilityReason: String, Codable, Sendable, Equatable, CaseIterable {
    case missingOvernightVitals = "missing_overnight_vitals"
    case missingWorkloadHistory = "missing_workload_history"
    case missingHeartRateBaselines = "missing_heart_rate_baselines"
    case noObservationsAvailable = "no_observations_available"

    public var titleUk: String {
        switch self {
        case .missingOvernightVitals:
            return "Недостатньо нічних біомаркерів (HRV, RHR або ранкового заряду)"
        case .missingWorkloadHistory:
            return "Недостатньо історії тренувального навантаження (ACWR)"
        case .missingHeartRateBaselines:
            return "Не задані базові межі пульсу (спокій та максимум ЧСС)"
        case .noObservationsAvailable:
            return "Немає зафіксованих фізіологічних спостережень за день"
        }
    }
}

public struct PrescriptionEvaluationOutcome: Sendable, Equatable {
    public let plan: TrainingPrescriptionPlan?
    public let unavailabilityReasons: [PrescriptionUnavailabilityReason]
    public let isProvisionalWorkload: Bool

    public init(
        plan: TrainingPrescriptionPlan?,
        unavailabilityReasons: [PrescriptionUnavailabilityReason],
        isProvisionalWorkload: Bool
    ) {
        self.plan = plan
        self.unavailabilityReasons = unavailabilityReasons
        self.isProvisionalWorkload = isProvisionalWorkload
    }
}

// MARK: - Training Prescription Service

public enum TrainingPrescriptionService {

    /// Evaluates today's prescription strictly from observed physiology inputs.
    /// Never fabricates synthetic battery (82%), vitals (.optimal), or workload loads (45.0).
    public static func evaluate(
        queueState: RollingQueueState,
        config: TrainingGoalConfig = TrainingGoalConfig(),
        vitalsEvaluation: OvernightVitalsEvaluation?,
        morningBodyBattery: Int?,
        workloadEvaluation: ACWREvaluation?,
        rolling3dEnergyBalanceKcal: Double? = nil,
        efSamples: [Double] = [],
        recentLongRunDriftsPct: [Double] = [],
        efDelta30dPct: Double? = nil,
        restingHr: Double? = nil,
        maxHr: Double? = nil,
        carbDriftSlope: Double? = nil
    ) -> PrescriptionEvaluationOutcome {
        var unavailabilityReasons: [PrescriptionUnavailabilityReason] = []

        let hasMeasuredVitals = vitalsEvaluation.map { !$0.allPillars.isEmpty } ?? false
        if !hasMeasuredVitals || morningBodyBattery == nil {
            unavailabilityReasons.append(.missingOvernightVitals)
        }

        if workloadEvaluation == nil || workloadEvaluation?.coverage.confidence == .insufficient {
            unavailabilityReasons.append(.missingWorkloadHistory)
        }

        let validRestingHr = restingHr.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let validMaxHr = maxHr.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let hasValidHeartRateBaselines: Bool = {
            guard let rhr = validRestingHr, let mhr = validMaxHr else { return false }
            return mhr > rhr
        }()
        if !hasValidHeartRateBaselines {
            unavailabilityReasons.append(.missingHeartRateBaselines)
        }

        guard unavailabilityReasons.isEmpty,
              let vitals = vitalsEvaluation,
              let battery = morningBodyBattery,
              let workload = workloadEvaluation,
              let resolvedRestingHr = validRestingHr,
              let resolvedMaxHr = validMaxHr else {
            return PrescriptionEvaluationOutcome(
                plan: nil,
                unavailabilityReasons: unavailabilityReasons,
                isProvisionalWorkload: false
            )
        }

        let isProvisional = workload.coverage.confidence == .provisional
        let effectiveConfig = TrainingGoalConfig(
            weeklyRunDaysTarget: config.weeklyRunDaysTarget,
            maxSessionDurationMin: config.maxSessionDurationMin,
            targetACWRRatio: isProvisional ? min(config.targetACWRRatio, 1.00) : config.targetACWRRatio
        )
        let effectiveEfDelta = isProvisional ? min(0.0, efDelta30dPct ?? 0.0) : (efDelta30dPct ?? 0.0)

        let plan = TrainingPrescriptionEngine.prescribeTodayAndHorizon(
            queueState: queueState,
            config: effectiveConfig,
            previousAcuteLoad: workload.acuteLoad,
            previousChronicLoad: workload.chronicLoad,
            vitalsState: vitals.state,
            hrvZScore: vitals.hrvPillar.zScore ?? 0.0,
            morningBodyBattery: battery,
            rolling3dEnergyBalanceKcal: rolling3dEnergyBalanceKcal ?? 0.0,
            efSamples: efSamples,
            recentLongRunDriftsPct: recentLongRunDriftsPct,
            efDelta30dPct: effectiveEfDelta,
            restingHr: resolvedRestingHr,
            maxHr: resolvedMaxHr,
            carbDriftSlope: carbDriftSlope ?? 0.0
        )

        return PrescriptionEvaluationOutcome(
            plan: plan,
            unavailabilityReasons: [],
            isProvisionalWorkload: isProvisional
        )
    }
}
