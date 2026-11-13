import XCTest
@testable import Lifecore

@MainActor
final class NavigationTests: XCTestCase {

    func testMainTabNavigationSwitchesTabsAndPreservesTabAcrossSettingsLifecycle() {
        let nav = MainTabNavigationState()

        XCTAssertEqual(nav.selectedTab, .today)
        XCTAssertFalse(nav.isShowingSettings)
        XCTAssertNil(nav.activeSettingsRoute)

        nav.selectTab(.workouts)
        XCTAssertEqual(nav.selectedTab, .workouts)

        nav.selectTab(.nutrition)
        XCTAssertEqual(nav.selectedTab, .nutrition)

        nav.selectTab(.trends)
        XCTAssertEqual(nav.selectedTab, .trends)

        // Open Settings root, then navigate to Coach Memory
        nav.openSettings()
        XCTAssertTrue(nav.isShowingSettings)
        XCTAssertNil(nav.activeSettingsRoute)

        nav.openSettings(route: .coachMemory)
        XCTAssertTrue(nav.isShowingSettings)
        XCTAssertEqual(nav.activeSettingsRoute, .coachMemory)
        XCTAssertEqual(nav.selectedTab, .trends)

        // Close Settings and verify selected tab is preserved
        nav.closeSettings()
        XCTAssertFalse(nav.isShowingSettings)
        XCTAssertNil(nav.activeSettingsRoute)
        XCTAssertEqual(nav.selectedTab, .trends)
    }

    func testSettingsSectionRouteExposesAllFiveRoutesWithUniqueIDsAndUkrainianCopy() {
        let routes = SettingsSectionRoute.allCases
        XCTAssertEqual(routes.count, 5)
        XCTAssertEqual(
            Set(routes),
            Set([.athleteProfile, .healthAccess, .aiSetup, .accountSync, .coachMemory])
        )

        let accessibilityIDs = routes.map(\.accessibilityIdentifier)
        XCTAssertEqual(Set(accessibilityIDs).count, 5, "Every Settings route must have a unique accessibility identifier")
        XCTAssertEqual(
            Set(accessibilityIDs),
            Set([
                "settings_row_athlete_profile",
                "settings_row_health_access",
                "settings_row_ai_setup",
                "settings_row_account_sync",
                "settings_row_coach_memory"
            ])
        )

        for route in routes {
            XCTAssertFalse(route.titleUk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(route.subtitleUk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(route.systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testScreenStatePreservesRetainedContentAndDistinguishesAllCases() {
        let loadingState: ScreenState<String> = .loading
        XCTAssertTrue(loadingState.isLoading)
        XCTAssertNil(loadingState.value)
        XCTAssertFalse(loadingState.isRefreshing)
        XCTAssertFalse(loadingState.isStale)

        let emptyState: ScreenState<String> = .empty
        XCTAssertFalse(emptyState.isLoading)
        XCTAssertNil(emptyState.value)

        let unavailableState: ScreenState<String> = .unavailable(message: "Apple Health недоступний")
        XCTAssertFalse(unavailableState.isLoading)
        XCTAssertNil(unavailableState.value)
        if case .unavailable(let message) = unavailableState {
            XCTAssertEqual(message, "Apple Health недоступний")
        } else {
            XCTFail("Expected .unavailable state")
        }

        let contentState: ScreenState<String> = .content("104 мс", isRefreshing: true, isStale: false)
        XCTAssertEqual(contentState.value, "104 мс")
        XCTAssertTrue(contentState.isRefreshing)
        XCTAssertFalse(contentState.isStale)
        XCTAssertFalse(contentState.isLoading)

        let staleContentState: ScreenState<String> = .content("98 мс", isRefreshing: false, isStale: true)
        XCTAssertEqual(staleContentState.value, "98 мс")
        XCTAssertFalse(staleContentState.isRefreshing)
        XCTAssertTrue(staleContentState.isStale)

        let retainedFailure: ScreenState<String> = .failed(
            message: "Тимчасова помилка мережі",
            retained: "2 180 ккал"
        )
        XCTAssertEqual(retainedFailure.value, "2 180 ккал")
        XCTAssertFalse(retainedFailure.isLoading)
        XCTAssertNotEqual(retainedFailure, emptyState)
        XCTAssertNotEqual(retainedFailure, unavailableState)

        let unretainedFailure: ScreenState<String> = .failed(
            message: "Помилка без кешу",
            retained: nil
        )
        XCTAssertNil(unretainedFailure.value)
        XCTAssertNotEqual(unretainedFailure, retainedFailure)
    }

    func testLayoutTokensAndMetricStatusToneDefinitions() {
        XCTAssertEqual(LifecoreLayout.pageInset, 16)
        XCTAssertEqual(LifecoreLayout.spacing4, 4)
        XCTAssertEqual(LifecoreLayout.spacing8, 8)
        XCTAssertEqual(LifecoreLayout.spacing12, 12)
        XCTAssertEqual(LifecoreLayout.spacing16, 16)
        XCTAssertEqual(LifecoreLayout.spacing24, 24)
        XCTAssertEqual(LifecoreLayout.spacing32, 32)
        XCTAssertEqual(LifecoreLayout.minTouchTarget, 44)
        XCTAssertEqual(MetricStatusTone.allCases.count, 6)
    }
}
