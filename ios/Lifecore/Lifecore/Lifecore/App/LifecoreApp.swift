import SwiftUI
import SwiftData

@main
struct LifecoreApp: App {
    private let environment: AppEnvironment

    init() {
        self.environment = AppEnvironment.current
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
                .environment(\.appEnvironment, environment)
        }
        .modelContainer(environment.modelContainer)
    }
}
