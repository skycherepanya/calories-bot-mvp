import Foundation
import Combine
import SwiftUI

/// Main-actor view model for the Today tab dashboard.
/// Strictly consumes `DailySnapshotCoordinator` via Combine subscription.
/// Never calculates synthetic fallbacks, never fabricates missing biometrics.
@MainActor
public final class TodayViewModel: ObservableObject {

    @Published public private(set) var state: ScreenState<DailyDashboardSnapshot>
    @Published public var isShowingEvidence: Bool = false
    @Published public var isShowingProfile: Bool = false

    public let coordinator: DailySnapshotCoordinator
    private var cancellables = Set<AnyCancellable>()

    public init(coordinator: DailySnapshotCoordinator? = nil) {
        let resolvedCoordinator = coordinator ?? AppEnvironment.current.snapshotCoordinator
        self.coordinator = resolvedCoordinator
        self.state = resolvedCoordinator.state

        resolvedCoordinator.$state
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)
    }

    public var snapshot: DailyDashboardSnapshot? {
        state.value
    }

    public var isRefreshing: Bool {
        state.isRefreshing
    }

    public var isStale: Bool {
        state.isStale
    }

    public var currentDay: DietaryDay {
        coordinator.currentDay
    }

    public func refresh(force: Bool = false) async {
        await coordinator.refresh(day: coordinator.currentDay, force: force)
    }

    public func openEvidence() {
        isShowingEvidence = true
    }

    public func openWorkout(onNavigate: () -> Void) {
        onNavigate()
    }
}
