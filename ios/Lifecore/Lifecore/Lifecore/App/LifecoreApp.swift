import SwiftUI
import SwiftData

@main
struct LifecoreApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(LifecoreDataStore.shared.container)
    }
}
