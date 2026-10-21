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
        hrvMethod: .hybridRMSSD
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

    public func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
