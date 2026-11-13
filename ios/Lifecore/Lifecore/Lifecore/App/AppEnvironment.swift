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
    func saveMeal(meal: MealRecord) async throws
    func deleteMeal(mealId: UUID) async throws
}

public protocol AIProvider: Sendable {
    var isMock: Bool { get }
    func analyzeFoodDescription(_ text: String) async throws -> MealNutrition
    func analyzeFood(imageJpegData: Data?, textDescription: String?) async throws -> MealNutrition
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

    public func saveMeal(meal: MealRecord) async throws {
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
        MealNutrition(
            mealName: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Вівсянка з ягодами" : text,
            kcal: 320,
            protein: 14.0,
            fat: 6.0,
            carbs: 52.0,
            weightG: 300,
            confidence: 0.92,
            tags: ["whole_food", "solid"],
            micronutrients: nil,
            aminoAcids: nil
        )
    }

    public func analyzeFood(imageJpegData: Data?, textDescription: String?) async throws -> MealNutrition {
        let name = textDescription ?? "Фото страви"
        return try await analyzeFoodDescription(name)
    }

    public func generateDebrief(dossier: AssembledHealthDossier) async throws -> StructuredWorkoutDebrief {
        StructuredWorkoutDebrief(
            headlineUk: "Детермінований розбір тренування (fixture mode)",
            regimeBadgeUk: "Аеробна база",
            regimeTone: "teal",
            executionAnalysisUk: "Темп і пульс відповідали цільовому аеробному порогу без надмірного серцевого дрейфу.",
            benchmarkComparisonUk: "Продуктивність стабільна порівняно з аналогічними тренуваннями.",
            rootCauseAndDirectiveUk: "Повноцінне відновлення та достатній сон забезпечили високу якість сесії.",
            evidencePills: [],
            followUpQuestionsUk: []
        )
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

    public func saveMeal(meal: MealRecord) async throws {
        try await HealthKitManager.shared.saveMealToHealthKit(meal: meal, date: meal.createdAt)
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

    public func analyzeFood(imageJpegData: Data?, textDescription: String?) async throws -> MealNutrition {
        try await GeminiService.shared.analyzeFood(imageJpegData: imageJpegData, textDescription: textDescription)
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
    public let id: UUID
    public let mode: AppEnvironmentMode
    public var isFixtureMode: Bool { mode == .fixture }
    public let modelContainer: ModelContainer
    public let healthProvider: any HealthDataProvider
    public let aiProvider: any AIProvider
    public let syncProvider: any SyncProvider

    public init(
        id: UUID = UUID(),
        mode: AppEnvironmentMode,
        modelContainer: ModelContainer,
        healthProvider: any HealthDataProvider,
        aiProvider: any AIProvider,
        syncProvider: any SyncProvider
    ) {
        self.id = id
        self.mode = mode
        self.modelContainer = modelContainer
        self.healthProvider = healthProvider
        self.aiProvider = aiProvider
        self.syncProvider = syncProvider
    }

    @MainActor
    public var snapshotCoordinator: DailySnapshotCoordinator {
        SnapshotCoordinatorRegistry.shared.coordinator(for: id, mode: mode)
    }

    // MARK: - Factory Constructors

    public static func live() -> AppEnvironment {
        AppEnvironment(
            mode: .live,
            modelContainer: LifecoreDataStore.shared.persistentContainer,
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
        let schema = LifecoreDataStore.sharedSchema
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
        Task { @MainActor in
            SnapshotCoordinatorRegistry.shared.reset()
        }
    }
}

@MainActor
private final class SnapshotCoordinatorRegistry {
    static let shared = SnapshotCoordinatorRegistry()
    private var coordinators: [UUID: DailySnapshotCoordinator] = [:]

    func coordinator(for environmentID: UUID, mode: AppEnvironmentMode) -> DailySnapshotCoordinator {
        if let existing = coordinators[environmentID] {
            return existing
        }
        let dataSource: any DailySnapshotDataSource = mode == .fixture
            ? FixtureDailySnapshotDataSource()
            : LiveDailySnapshotDataSource()
        let created = DailySnapshotCoordinator(dataSource: dataSource)
        coordinators[environmentID] = created
        return created
    }

    func reset() {
        coordinators.removeAll()
    }
}

// MARK: - Thread-Safe Storage

private final class EnvironmentStorage: Sendable {
    private let state = OSAllocatedUnfairLock<AppEnvironment?>(initialState: nil)

    func get() -> AppEnvironment {
        if let existing = state.withLock({ $0 }) {
            return existing
        }
        let created = AppEnvironment.isFixtureLaunchRequested ? AppEnvironment.fixture() : AppEnvironment.live()
        return state.withLock { current in
            if let current = current {
                return current
            }
            current = created
            return created
        }
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
