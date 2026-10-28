import SwiftUI
import SwiftData

@main
struct LifecoreApp: App {
    init() {
        #if DEBUG
        let results = MathEngineVerification.runAllVerifications()
        for r in results {
            print("[VERIFICATION] \(r.testName): \(r.passed ? "PASS" : "FAIL") - \(r.details)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
        }
        .modelContainer(LifecoreDataStore.shared.container)
    }
}
