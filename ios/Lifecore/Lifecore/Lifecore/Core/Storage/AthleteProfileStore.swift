import Foundation
import Combine

public enum HRVCalculationMethod: String, Codable, CaseIterable, Sendable {
    case hybridRMSSD = "rmssd_hybrid" // Bevel-style beat-to-beat RMSSD with ln(SDNN) fallback
    case appleSDNN = "sdnn_only"      // Native Apple Health SDNN with ln(SDNN) normalization
}

public struct AthleteProfile: Codable, Sendable, Equatable {
    public var weightKg: Double
    public var heightCm: Double
    public var ageYears: Int
    public var maxHeartRateBpm: Double
    public var restingHeartRateBaselineBpm: Double
    public var hrvBaselineMs: Double
    public var wristTempBaselineCelsius: Double
    public var respiratoryRateBaselineBpm: Double
    public var spo2BaselinePct: Double
    public var bmrKcalPerDay: Double
    public var activeMoveGoalKcal: Double
    public var targetCaloriesKcal: Double
    public var targetProteinG: Double
    public var targetFatG: Double
    public var targetCarbsG: Double
    public var targetSleepHours: Double
    public var hrvMethod: HRVCalculationMethod
    public var readinessWeights: ReadinessWeightVector = ReadinessWeightVector()
    public var rpeCalibrationCount: Int = 0
    public var lastRpeCalibrationDate: String? = nil

    public init(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        maxHeartRateBpm: Double,
        restingHeartRateBaselineBpm: Double,
        hrvBaselineMs: Double,
        wristTempBaselineCelsius: Double,
        respiratoryRateBaselineBpm: Double,
        spo2BaselinePct: Double,
        bmrKcalPerDay: Double,
        activeMoveGoalKcal: Double,
        targetCaloriesKcal: Double,
        targetProteinG: Double,
        targetFatG: Double,
        targetCarbsG: Double,
        targetSleepHours: Double,
        hrvMethod: HRVCalculationMethod,
        readinessWeights: ReadinessWeightVector = ReadinessWeightVector(),
        rpeCalibrationCount: Int = 0,
        lastRpeCalibrationDate: String? = nil
    ) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.ageYears = ageYears
        self.maxHeartRateBpm = maxHeartRateBpm
        self.restingHeartRateBaselineBpm = restingHeartRateBaselineBpm
        self.hrvBaselineMs = hrvBaselineMs
        self.wristTempBaselineCelsius = wristTempBaselineCelsius
        self.respiratoryRateBaselineBpm = respiratoryRateBaselineBpm
        self.spo2BaselinePct = spo2BaselinePct
        self.bmrKcalPerDay = bmrKcalPerDay
        self.activeMoveGoalKcal = activeMoveGoalKcal
        self.targetCaloriesKcal = targetCaloriesKcal
        self.targetProteinG = targetProteinG
        self.targetFatG = targetFatG
        self.targetCarbsG = targetCarbsG
        self.targetSleepHours = targetSleepHours
        self.hrvMethod = hrvMethod
        self.readinessWeights = readinessWeights
        self.rpeCalibrationCount = rpeCalibrationCount
        self.lastRpeCalibrationDate = lastRpeCalibrationDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.weightKg = try container.decode(Double.self, forKey: .weightKg)
        self.heightCm = try container.decode(Double.self, forKey: .heightCm)
        self.ageYears = try container.decode(Int.self, forKey: .ageYears)
        self.maxHeartRateBpm = try container.decode(Double.self, forKey: .maxHeartRateBpm)
        self.restingHeartRateBaselineBpm = try container.decode(Double.self, forKey: .restingHeartRateBaselineBpm)
        self.hrvBaselineMs = try container.decode(Double.self, forKey: .hrvBaselineMs)
        self.wristTempBaselineCelsius = try container.decode(Double.self, forKey: .wristTempBaselineCelsius)
        self.respiratoryRateBaselineBpm = try container.decode(Double.self, forKey: .respiratoryRateBaselineBpm)
        self.spo2BaselinePct = try container.decode(Double.self, forKey: .spo2BaselinePct)
        self.bmrKcalPerDay = try container.decode(Double.self, forKey: .bmrKcalPerDay)
        self.activeMoveGoalKcal = try container.decode(Double.self, forKey: .activeMoveGoalKcal)
        self.targetCaloriesKcal = try container.decode(Double.self, forKey: .targetCaloriesKcal)
        self.targetProteinG = try container.decode(Double.self, forKey: .targetProteinG)
        self.targetFatG = try container.decode(Double.self, forKey: .targetFatG)
        self.targetCarbsG = try container.decode(Double.self, forKey: .targetCarbsG)
        self.targetSleepHours = try container.decode(Double.self, forKey: .targetSleepHours)
        self.hrvMethod = try container.decodeIfPresent(HRVCalculationMethod.self, forKey: .hrvMethod) ?? .hybridRMSSD
        self.readinessWeights = try container.decodeIfPresent(ReadinessWeightVector.self, forKey: .readinessWeights) ?? ReadinessWeightVector()
        self.rpeCalibrationCount = try container.decodeIfPresent(Int.self, forKey: .rpeCalibrationCount) ?? 0
        self.lastRpeCalibrationDate = try container.decodeIfPresent(String.self, forKey: .lastRpeCalibrationDate)
    }

    public static let sashaDefault = AthleteProfile(
        weightKg: 78.6,
        heightCm: 181.0,
        ageYears: 28,
        maxHeartRateBpm: 192.0,
        restingHeartRateBaselineBpm: 49.0,
        hrvBaselineMs: 102.0,
        wristTempBaselineCelsius: 36.40,
        respiratoryRateBaselineBpm: 14.2,
        spo2BaselinePct: 97.8,
        bmrKcalPerDay: 1750.0,
        activeMoveGoalKcal: 650.0,
        targetCaloriesKcal: 2150.0,
        targetProteinG: 165.0,
        targetFatG: 70.0,
        targetCarbsG: 215.0,
        targetSleepHours: 7.5,
        hrvMethod: .hybridRMSSD,
        readinessWeights: ReadinessWeightVector(),
        rpeCalibrationCount: 0,
        lastRpeCalibrationDate: nil
    )
}

@MainActor
public final class AthleteProfileStore: ObservableObject {
    public static let shared = AthleteProfileStore()
    private let storageKey = "lifecore.athlete_profile.v3"

    @Published public var profile: AthleteProfile {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AthleteProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = .sashaDefault
        }
    }

    public func recordRPEFeedback(_ feedback: Int, hrvWasLow: Bool, sleepWasLow: Bool, dietaryDate: String) {
        let newWeights = AdaptivePhysiologyEngine.calibrateReadinessWeights(
            currentWeights: profile.readinessWeights,
            rpeFeedback: feedback,
            hrvWasLow: hrvWasLow,
            sleepWasLow: sleepWasLow
        )
        profile.readinessWeights = newWeights
        profile.rpeCalibrationCount += 1
        profile.lastRpeCalibrationDate = dietaryDate
        save()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
