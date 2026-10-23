import Foundation
import SwiftData
import Combine

@Model
public final class AthleteTrainingPlanState {
    @Attribute(.unique) public var id: String
    public var currentQueueIndex: Int
    public var weeklyRunFrequency: Int
    public var targetSessionDurationCapMin: Double
    public var targetACWRRatio: Double
    public var clubRunOverrideToday: Bool
    public var lastUpdatedDateString: String
    public var updatedAt: Date

    public init(
        id: String = "primary_athlete_plan_state",
        currentQueueIndex: Int = 0,
        weeklyRunFrequency: Int = 4,
        targetSessionDurationCapMin: Double = 60.0,
        targetACWRRatio: Double = 1.08,
        clubRunOverrideToday: Bool = false,
        lastUpdatedDateString: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.currentQueueIndex = currentQueueIndex
        self.weeklyRunFrequency = weeklyRunFrequency
        self.targetSessionDurationCapMin = targetSessionDurationCapMin
        self.targetACWRRatio = targetACWRRatio
        self.clubRunOverrideToday = clubRunOverrideToday
        self.lastUpdatedDateString = lastUpdatedDateString
        self.updatedAt = updatedAt
    }
}

@MainActor
public final class TrainingPlanStore: ObservableObject {
    public static let shared = TrainingPlanStore()

    @Published public var queueState: RollingQueueState
    @Published public var goalConfig: TrainingGoalConfig

    private init() {
        let context = LifecoreDataStore.shared.context
        let descriptor = FetchDescriptor<AthleteTrainingPlanState>()
        if let existing = (try? context.fetch(descriptor))?.first {
            self.queueState = RollingQueueState(
                currentIndex: existing.currentQueueIndex,
                clubOrCustomRunOverrideToday: existing.clubRunOverrideToday,
                lastAdvancedDateString: existing.lastUpdatedDateString
            )
            self.goalConfig = TrainingGoalConfig(
                weeklyRunDaysTarget: existing.weeklyRunFrequency,
                maxSessionDurationMin: existing.targetSessionDurationCapMin,
                targetACWRRatio: existing.targetACWRRatio
            )
        } else {
            let initial = AthleteTrainingPlanState()
            context.insert(initial)
            try? context.save()
            self.queueState = RollingQueueState()
            self.goalConfig = TrainingGoalConfig()
        }
    }

    public func toggleClubOrCustomRunToday() {
        queueState.clubOrCustomRunOverrideToday.toggle()
        if queueState.clubOrCustomRunOverrideToday {
            queueState.currentIndex = (queueState.currentIndex + 1) % WorkoutArchetype.rollingCycle.count
        }
        persist()
    }

    public func advanceQueueSlot() {
        queueState.currentIndex = (queueState.currentIndex + 1) % WorkoutArchetype.rollingCycle.count
        queueState.clubOrCustomRunOverrideToday = false
        persist()
    }

    public func persist() {
        let context = LifecoreDataStore.shared.context
        let descriptor = FetchDescriptor<AthleteTrainingPlanState>()
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.currentQueueIndex = queueState.currentIndex
            existing.clubRunOverrideToday = queueState.clubOrCustomRunOverrideToday
            existing.weeklyRunFrequency = goalConfig.weeklyRunDaysTarget
            existing.targetSessionDurationCapMin = goalConfig.maxSessionDurationMin
            existing.targetACWRRatio = goalConfig.targetACWRRatio
            existing.updatedAt = Date()
            try? context.save()
        }
    }
}
