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
                    Label("Сьогодні", systemImage: "bolt.heart.fill")
                        .accessibilityIdentifier("tab_today")
                }
                .tag(AppTab.today)
                .accessibilityIdentifier("screen_today")

            WorkoutsView()
                .tabItem {
                    Label("Тренування", systemImage: "figure.run")
                        .accessibilityIdentifier("tab_workouts")
                }
                .tag(AppTab.workouts)
                .accessibilityIdentifier("screen_workouts")

            NutritionView()
                .tabItem {
                    Label("Харчування", systemImage: "fork.knife")
                        .accessibilityIdentifier("tab_nutrition")
                }
                .tag(AppTab.nutrition)
                .accessibilityIdentifier("screen_nutrition")

            TrendsView()
                .tabItem {
                    Label("Тренди", systemImage: "chart.line.uptrend.xyaxis")
                        .accessibilityIdentifier("tab_trends")
                }
                .tag(AppTab.trends)
                .accessibilityIdentifier("screen_trends")
        }
        .tint(.cyan)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
