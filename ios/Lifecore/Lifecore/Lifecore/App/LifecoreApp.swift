import SwiftUI
import SwiftData

@main
struct LifecoreApp: App {
    private let environment: AppEnvironment
    @StateObject private var navigationState = MainTabNavigationState()

    init() {
        self.environment = AppEnvironment.current
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(navigationState: navigationState)
                .preferredColorScheme(.light)
                .environment(\.appEnvironment, environment)
        }
        .modelContainer(environment.modelContainer)
    }
}
