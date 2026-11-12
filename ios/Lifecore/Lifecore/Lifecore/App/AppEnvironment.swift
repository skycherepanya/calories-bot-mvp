import Foundation
import SwiftData
import SwiftUI
import os

// MARK: - App Environment Mode

public enum AppEnvironmentMode: String, Sendable, Equatable {
    case live
    case fixture
}

// MARK: - Provider Abstractions

public protocol HealthDataProvider: Sendable {
    var isMock: Bool { get }
    func requestAuthorization() async throws
    func saveMeal(id: UUID, name: String, calories: Double, proteinGrams: Double, fatGrams: Double, carbsGrams: Double, sodiumMg: Double, date: Date) async throws
    func deleteMeal(mealId: UUID) async throws
}

public protocol AIProvider: Sendable {
    var isMock: Bool { get }
    func analyzeFoodDescription(_ text: String) async throws -> MealNutrition
    func generateDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief
}

public protocol SyncProvider: Sendable {
    var isMock: Bool { get }
    func syncPendingMeals() async throws -> Int
    func syncPendingAnalyses() async throws -> Int
}

// MARK: - Mock Implementations (Fixture Mode)

public actor MockHealthDataProvider: HealthDataProvider {
    public nonisolated let isMock: Bool = true
    public private(set) var savedMealsCount: Int = 0
    public private(set) var deletedMealsCount: Int = 0

    public init() {}

    public func requestAuthorization() async throws {
        // No-op in fixture mode; no HealthKit prompts
    }

    public func saveMeal(id: UUID, name: String, calories: Double, proteinGrams: Double, fatGrams: Double, carbsGrams: Double, sodiumMg: Double, date: Date) async throws {
        savedMealsCount += 1
    }

    public func deleteMeal(mealId: UUID) async throws {
        deletedMealsCount += 1
    }
}

public final class MockAIProvider: AIProvider, Sendable {
    public let isMock: Bool = true

    public init() {}

    public func analyzeFoodDescription(_ text: String) async throws -> MealNutrition {
        GeminiService.shared.generateOfflineMeal(textDescription: text)
    }

    public func generateDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief {
        GeminiService.shared.generateStructuredWorkoutDebriefOffline(dossier: dossier)
    }
}

public final class MockSyncProvider: SyncProvider, Sendable {
    public let isMock: Bool = true

    public init() {}

    public func syncPendingMeals() async throws -> Int {
        return 0
    }

    public func syncPendingAnalyses() async throws -> Int {
        return 0
    }
}

// MARK: - Live Implementations

public final class LiveHealthDataProvider: HealthDataProvider, Sendable {
    public let isMock: Bool = false

    public init() {}

    public func requestAuthorization() async throws {
        try await HealthKitManager.shared.requestAuthorization()
    }

    public func saveMeal(id: UUID, name: String, calories: Double, proteinGrams: Double, fatGrams: Double, carbsGrams: Double, sodiumMg: Double, date: Date) async throws {
        let record = MealRecord(
            id: id,
            name: name,
            kcal: calories,
            proteinG: proteinGrams,
            fatG: fatGrams,
            carbsG: carbsGrams,
            tags: [],
            dietaryDate: FoodPrompt.dietaryDate(for: date),
            createdAt: date
        )
        try await HealthKitManager.shared.saveMealToHealthKit(meal: record, date: date)
    }

    public func deleteMeal(mealId: UUID) async throws {
        try await HealthKitManager.shared.deleteMealFromHealthKit(mealId: mealId)
    }
}

public final class LiveAIProvider: AIProvider, Sendable {
    public let isMock: Bool = false

    public init() {}

    public func analyzeFoodDescription(_ text: String) async throws -> MealNutrition {
        try await GeminiService.shared.analyzeFood(imageJpegData: nil, textDescription: text)
    }

    public func generateDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief {
        try await GeminiService.shared.generateStructuredCoachDebrief(dossier: dossier)
    }
}

public final class LiveSyncProvider: SyncProvider, Sendable {
    public let isMock: Bool = false

    public init() {}

    public func syncPendingMeals() async throws -> Int {
        try await SupabaseSyncService.shared.syncPendingMeals()
    }

    public func syncPendingAnalyses() async throws -> Int {
        try await SupabaseSyncService.shared.syncPendingWorkoutAnalyses()
    }
}

// MARK: - AppEnvironment

public struct AppEnvironment: Sendable {
    public let mode: AppEnvironmentMode
    public var isFixtureMode: Bool { mode == .fixture }
    public let modelContainer: ModelContainer
    public let healthProvider: any HealthDataProvider
    public let aiProvider: any AIProvider
    public let syncProvider: any SyncProvider

    public init(
        mode: AppEnvironmentMode,
        modelContainer: ModelContainer,
        healthProvider: any HealthDataProvider,
        aiProvider: any AIProvider,
        syncProvider: any SyncProvider
    ) {
        self.mode = mode
        self.modelContainer = modelContainer
        self.healthProvider = healthProvider
        self.aiProvider = aiProvider
        self.syncProvider = syncProvider
    }

    // MARK: - Factory Constructors

    public static func live() -> AppEnvironment {
        AppEnvironment(
            mode: .live,
            modelContainer: LifecoreDataStore.shared.container,
            healthProvider: LiveHealthDataProvider(),
            aiProvider: LiveAIProvider(),
            syncProvider: LiveSyncProvider()
        )
    }

    public static func fixture(container: ModelContainer? = nil) -> AppEnvironment {
        let selectedContainer = container ?? makeIsolatedModelContainer()
        return AppEnvironment(
            mode: .fixture,
            modelContainer: selectedContainer,
            healthProvider: MockHealthDataProvider(),
            aiProvider: MockAIProvider(),
            syncProvider: MockSyncProvider()
        )
    }

    public static func makeIsolatedModelContainer() -> ModelContainer {
        let schema = Schema([
            MealEntity.self,
            WorkoutAnalysisEntity.self,
            AthleteTrainingPlanState.self,
            AthleteMemoryEntity.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize isolated in-memory ModelContainer: \(error)")
        }
    }

    // MARK: - Global Resolver

    private static let storage = EnvironmentStorage()

    public static var isFixtureLaunchRequested: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--fixture") { return true }
        if let idx = args.firstIndex(of: "-LifecoreFixtureMode"), idx + 1 < args.count {
            let val = args[idx + 1]
            if val == "1" || val.lowercased() == "true" { return true }
        }
        let env = ProcessInfo.processInfo.environment
        if env["LIFECORE_FIXTURE_MODE"] == "1" || env["LIFECORE_FIXTURE_MODE"]?.lowercased() == "true" {
            return true
        }
        if env["XCTestConfigurationFilePath"] != nil {
            return true
        }
        return false
    }

    public static var current: AppEnvironment {
        get { storage.get() }
        set { storage.set(newValue) }
    }

    public static func reset() {
        storage.set(nil)
    }
}

// MARK: - Thread-Safe Storage

private final class EnvironmentStorage: Sendable {
    private let state = OSAllocatedUnfairLock<AppEnvironment?>(initialState: nil)

    func get() -> AppEnvironment {
        if let custom = state.withLock({ $0 }) {
            return custom
        }
        return AppEnvironment.isFixtureLaunchRequested ? AppEnvironment.fixture() : AppEnvironment.live()
    }

    func set(_ env: AppEnvironment?) {
        state.withLock { $0 = env }
    }
}

// MARK: - SwiftUI Environment Integration

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .current
}

extension EnvironmentValues {
    public var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
