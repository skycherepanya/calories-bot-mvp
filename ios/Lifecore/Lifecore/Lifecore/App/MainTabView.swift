import SwiftUI
import Combine

public enum AppTab: Hashable, Sendable {
    case today
    case workouts
    case nutrition
    case trends
}

private struct OpenLifecoreSettingsKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

public extension EnvironmentValues {
    var openLifecoreSettings: @MainActor @Sendable () -> Void {
        get { self[OpenLifecoreSettingsKey.self] }
        set { self[OpenLifecoreSettingsKey.self] = newValue }
    }
}

public struct SettingsToolbarButton: View {
    @Environment(\.openLifecoreSettings) private var openSettings

    public init() {}

    public var body: some View {
        Button {
            openSettings()
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(LifecoreTheme.accentPrimary)
        }
        .accessibilityLabel("Налаштування")
        .accessibilityHint("Відкриває профіль, дозволи Apple Health, ШІ та синхронізацію")
        .accessibilityIdentifier("btn_open_settings")
    }
}

@MainActor
public final class MainTabNavigationState: ObservableObject {
    @Published public var selectedTab: AppTab
    @Published public var isShowingSettings: Bool
    @Published public var activeSettingsRoute: SettingsSectionRoute?

    public init(
        selectedTab: AppTab = .today,
        isShowingSettings: Bool = false,
        activeSettingsRoute: SettingsSectionRoute? = nil
    ) {
        self.selectedTab = selectedTab
        self.isShowingSettings = isShowingSettings
        self.activeSettingsRoute = activeSettingsRoute
    }

    public func selectTab(_ tab: AppTab) {
        selectedTab = tab
    }

    public func openSettings(route: SettingsSectionRoute? = nil) {
        activeSettingsRoute = route
        isShowingSettings = true
    }

    public func closeSettings() {
        isShowingSettings = false
        activeSettingsRoute = nil
    }
}

public struct MainTabView: View {
    @StateObject private var ownedNavigationState = MainTabNavigationState()
    private let injectedNavigationState: MainTabNavigationState?

    public init(navigationState: MainTabNavigationState? = nil) {
        self.injectedNavigationState = navigationState
    }

    public var body: some View {
        MainTabShellView(navState: injectedNavigationState ?? ownedNavigationState)
    }
}

private struct MainTabShellView: View {
    @Environment(\.appEnvironment) private var appEnvironment
    @ObservedObject var navState: MainTabNavigationState

    var body: some View {
        TabView(selection: $navState.selectedTab) {
            TodayView(onNavigateToWorkouts: {
                navState.selectTab(.workouts)
            })
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
        .tint(LifecoreTheme.accentPrimary)
        .environment(\.openLifecoreSettings, { @MainActor in
            navState.openSettings()
        })
        .sheet(isPresented: $navState.isShowingSettings, onDismiss: {
            navState.activeSettingsRoute = nil
        }) {
            SettingsView(
                environment: appEnvironment,
                initialRoute: navState.activeSettingsRoute
            )
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.light)
}
