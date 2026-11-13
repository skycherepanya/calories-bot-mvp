import SwiftUI
import Combine

public enum AppTab: Hashable, Sendable {
    case today
    case workouts
    case nutrition
    case trends
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
            tabWithSettingsTrigger(
                TodayView(onNavigateToWorkouts: {
                    navState.selectTab(.workouts)
                })
            )
            .tabItem {
                Label("Сьогодні", systemImage: "bolt.heart.fill")
                    .accessibilityIdentifier("tab_today")
            }
            .tag(AppTab.today)
            .accessibilityIdentifier("screen_today")

            tabWithSettingsTrigger(WorkoutsView())
                .tabItem {
                    Label("Тренування", systemImage: "figure.run")
                        .accessibilityIdentifier("tab_workouts")
                }
                .tag(AppTab.workouts)
                .accessibilityIdentifier("screen_workouts")

            tabWithSettingsTrigger(NutritionView())
                .tabItem {
                    Label("Харчування", systemImage: "fork.knife")
                        .accessibilityIdentifier("tab_nutrition")
                }
                .tag(AppTab.nutrition)
                .accessibilityIdentifier("screen_nutrition")

            tabWithSettingsTrigger(TrendsView())
                .tabItem {
                    Label("Тренди", systemImage: "chart.line.uptrend.xyaxis")
                        .accessibilityIdentifier("tab_trends")
                }
                .tag(AppTab.trends)
                .accessibilityIdentifier("screen_trends")
        }
        .tint(LifecoreTheme.accentPrimary)
        .sheet(isPresented: $navState.isShowingSettings, onDismiss: {
            navState.activeSettingsRoute = nil
        }) {
            SettingsView(
                environment: appEnvironment,
                initialRoute: navState.activeSettingsRoute
            )
        }
    }

    /// Attaches a non-intrusive tab-level Settings trigger without nesting a second NavigationStack.
    private func tabWithSettingsTrigger<Content: View>(_ content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                Button {
                    navState.openSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(LifecoreTheme.accentPrimary)
                        .frame(
                            width: LifecoreLayout.minTouchTarget,
                            height: LifecoreLayout.minTouchTarget
                        )
                        .background(
                            Circle()
                                .fill(LifecoreTheme.semanticCard)
                        )
                        .overlay(
                            Circle()
                                .stroke(LifecoreTheme.semanticSeparator.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, LifecoreLayout.pageInset)
                .padding(.bottom, 76)
                .accessibilityLabel("Налаштування")
                .accessibilityHint("Відкриває профіль, дозволи Apple Health, ШІ та синхронізацію")
                .accessibilityIdentifier("btn_open_settings")
            }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.light)
}
