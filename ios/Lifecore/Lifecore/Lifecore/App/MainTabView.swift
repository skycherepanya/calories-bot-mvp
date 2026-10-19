import SwiftUI

public enum AppTab: Hashable {
    case today
    case workouts
    case nutrition
    case trends
}

public struct MainTabView: View {
    @State private var selectedTab: AppTab = .today

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "bolt.heart.fill")
                }
                .tag(AppTab.today)

            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }
                .tag(AppTab.workouts)

            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
                .tag(AppTab.nutrition)

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.trends)
        }
        .tint(.cyan)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
