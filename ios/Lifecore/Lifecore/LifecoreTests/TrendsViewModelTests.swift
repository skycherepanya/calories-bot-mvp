import XCTest
@testable import Lifecore

@MainActor
final class TrendsViewModelTests: XCTestCase {

    // MARK: - 1. ChartDomain Tests

    func testChartDomainWeightSpecificCases() {
        // [38] -> 36.5...39.5
        let range38 = ChartDomain.weight([38.0])
        XCTAssertNotNil(range38)
        XCTAssertEqual(range38?.lowerBound, 36.5)
        XCTAssertEqual(range38?.upperBound, 39.5)

        // [152] -> 150.5...153.5 (MUST NOT clip to 40...150)
        let range152 = ChartDomain.weight([152.0])
        XCTAssertNotNil(range152)
        XCTAssertEqual(range152?.lowerBound, 150.5)
        XCTAssertEqual(range152?.upperBound, 153.5)

        // [.nan, .infinity] -> nil
        let rangeNonFinite = ChartDomain.weight([Double.nan, Double.infinity])
        XCTAssertNil(rangeNonFinite)

        // [] -> nil
        let rangeEmpty = ChartDomain.weight([])
        XCTAssertNil(rangeEmpty)

        // Constant [72, 72] -> 70.5...73.5
        let rangeConstant = ChartDomain.weight([72.0, 72.0])
        XCTAssertNotNil(rangeConstant)
        XCTAssertEqual(rangeConstant?.lowerBound, 70.5)
        XCTAssertEqual(rangeConstant?.upperBound, 73.5)

        // Wide [35, 160] -> 22.5...172.5 (span = 125, padding = max(1.5, 12.5) = 12.5)
        let rangeWide = ChartDomain.weight([35.0, 160.0])
        XCTAssertNotNil(rangeWide)
        XCTAssertEqual(rangeWide?.lowerBound, 22.5)
        XCTAssertEqual(rangeWide?.upperBound, 172.5)
    }

    func testChartDomainSafeFiniteHelpers() {
        // HRV domain
        let hrvNormal = ChartDomain.hrvDomain([90.0, 110.0])
        XCTAssertNotNil(hrvNormal)
        XCTAssertLessThanOrEqual(hrvNormal!.lowerBound, 85.0)
        XCTAssertGreaterThanOrEqual(hrvNormal!.upperBound, 115.0)

        let hrvSingle = ChartDomain.hrvDomain([100.0])
        XCTAssertNotNil(hrvSingle)
        XCTAssertEqual(hrvSingle?.lowerBound, 95.0)
        XCTAssertEqual(hrvSingle?.upperBound, 105.0)

        XCTAssertNil(ChartDomain.hrvDomain([]))
        XCTAssertNil(ChartDomain.hrvDomain([Double.nan]))

        // RHR domain
        let rhrNormal = ChartDomain.rhrDomain([48.0, 56.0])
        XCTAssertNotNil(rhrNormal)
        XCTAssertLessThanOrEqual(rhrNormal!.lowerBound, 45.0)
        XCTAssertGreaterThanOrEqual(rhrNormal!.upperBound, 59.0)

        let rhrSingle = ChartDomain.rhrDomain([50.0])
        XCTAssertNotNil(rhrSingle)
        XCTAssertEqual(rhrSingle?.lowerBound, 47.0)
        XCTAssertEqual(rhrSingle?.upperBound, 53.0)

        XCTAssertNil(ChartDomain.rhrDomain([]))
        XCTAssertNil(ChartDomain.rhrDomain([Double.nan]))

        // ACWR domain
        let acwrNormal = ChartDomain.acwrDomain([1.1])
        XCTAssertNotNil(acwrNormal)
        XCTAssertLessThanOrEqual(acwrNormal!.lowerBound, 0.5)
        XCTAssertGreaterThanOrEqual(acwrNormal!.upperBound, 1.5)

        XCTAssertNil(ChartDomain.acwrDomain([]))
        XCTAssertNil(ChartDomain.acwrDomain([Double.nan]))

        // Aerobic Efficiency domain
        let efNormal = ChartDomain.aerobicEfficiencyDomain([1.25])
        XCTAssertNotNil(efNormal)
        XCTAssertLessThan(efNormal!.lowerBound, 1.25)
        XCTAssertGreaterThan(efNormal!.upperBound, 1.25)

        XCTAssertNil(ChartDomain.aerobicEfficiencyDomain([]))
        XCTAssertNil(ChartDomain.aerobicEfficiencyDomain([Double.nan]))
    }

    // MARK: - 2. Out-of-Order Range Responses Test

    func testOutOfOrderRangeResponsesDelayed30dAfterFast90dLeaves90d() async {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        let makeRecords: (Int) -> [DailyJoinedPhysiologyRecord] = { count in
            (0..<count).map { i in
                let d = calendar.date(byAdding: .day, value: -i, to: now) ?? now
                let comps = calendar.dateComponents([.year, .month, .day], from: d)
                let key = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
                return DailyJoinedPhysiologyRecord(
                    dateString: key,
                    date: d,
                    weightKg: 75.0,
                    workoutTrimp: 45.0
                )
            }
        }

        let records30 = makeRecords(30)
        let records90 = makeRecords(90)
        let snapshot30 = TrendsViewModel.makeSnapshot(rangeDays: 30, records: records30)
        let snapshot90 = TrendsViewModel.makeSnapshot(rangeDays: 90, records: records90)

        final class ContinuationHolder: @unchecked Sendable {
            var continuation: CheckedContinuation<TrendsSnapshot, Error>?
        }
        let holder = ContinuationHolder()

        let loader: TrendsDataLoader = { days in
            if days == 30 {
                return try await withCheckedThrowingContinuation { cont in
                    holder.continuation = cont
                }
            } else if days == 90 {
                return snapshot90
            }
            throw HealthKitError.invalidDateRange
        }

        let viewModel = TrendsViewModel(selectedRangeDays: 30, dataLoader: loader)

        // Launch slow 30d request
        let task30 = Task {
            await viewModel.load(rangeDays: 30)
        }

        // Wait briefly for task30 to suspend inside continuation
        for _ in 0..<10 {
            if holder.continuation != nil { break }
            await Task.yield()
        }

        // Fast 90d request completes immediately
        await viewModel.load(rangeDays: 90)

        XCTAssertEqual(viewModel.selectedRangeDays, 90)
        XCTAssertEqual(viewModel.state.value?.rangeDays, 90)
        XCTAssertEqual(viewModel.state.value?.records.count, 90)

        // Now resume the delayed 30d response AFTER 90d has resolved
        holder.continuation?.resume(returning: snapshot30)
        await task30.value

        // Must still leave selectedRangeDays == 90 and 90d records
        XCTAssertEqual(viewModel.selectedRangeDays, 90, "Delayed 30d response must not overwrite selectedRangeDays")
        XCTAssertEqual(viewModel.state.value?.rangeDays, 90, "Delayed 30d response must not overwrite 90d state")
        XCTAssertEqual(viewModel.state.value?.records.count, 90, "Delayed 30d response must not overwrite 90d records")
    }

    // MARK: - 3. Cancellation Resets Only Own Loading Flag Cleanly

    func testCancellationResetsOnlyItsOwnLoadingFlagCleanly() async {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        let records30 = (0..<30).map { i in
            let d = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            let comps = calendar.dateComponents([.year, .month, .day], from: d)
            let key = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
            return DailyJoinedPhysiologyRecord(dateString: key, date: d, weightKg: 74.0)
        }
        let snapshot30 = TrendsViewModel.makeSnapshot(rangeDays: 30, records: records30)

        final class HangingHolder: @unchecked Sendable {
            var continuation: CheckedContinuation<TrendsSnapshot, Error>?
        }
        let holder = HangingHolder()

        let loader: TrendsDataLoader = { days in
            if days == 30 {
                return snapshot30
            } else {
                return try await withCheckedThrowingContinuation { cont in
                    holder.continuation = cont
                }
            }
        }

        let viewModel = TrendsViewModel(selectedRangeDays: 30, dataLoader: loader)

        // Initial load completes with cached content
        await viewModel.load(rangeDays: 30)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertFalse(viewModel.state.isRefreshing)
        XCTAssertEqual(viewModel.state.value?.rangeDays, 30)

        // Launch 90d refresh in background task
        let refreshTask = Task {
            await viewModel.load(rangeDays: 90)
        }

        for _ in 0..<10 {
            if holder.continuation != nil { break }
            await Task.yield()
        }

        XCTAssertTrue(viewModel.state.isRefreshing, "Cached content should be retained with isRefreshing == true")

        // Cancel the in-flight refresh task
        refreshTask.cancel()
        holder.continuation?.resume(throwing: CancellationError())
        await refreshTask.value

        // isRefreshing must be reset to false without losing retained content
        XCTAssertFalse(viewModel.state.isRefreshing, "Cancellation must reset refreshing flag cleanly")
        XCTAssertEqual(viewModel.state.value?.rangeDays, 30, "Retained cached content must be preserved")
    }

    // MARK: - 4. 90d Loading Builds 90d Records and Labels Sub-Window Engine Coverage

    func test90dLoadingBuilds90dRecordsAndLabelsSubWindowEngineCoverageAccurately() async {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        let records90 = (0..<90).map { i in
            let d = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            let comps = calendar.dateComponents([.year, .month, .day], from: d)
            let key = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
            return DailyJoinedPhysiologyRecord(
                dateString: key,
                date: d,
                weightKg: i % 2 == 0 ? 76.5 : nil,
                sodiumMg: 2400.0,
                carbsG: 220.0,
                proteinG: 140.0,
                fatG: 65.0,
                overnightHrvMs: i % 3 == 0 ? 104.0 : nil,
                workoutTrimp: i % 2 == 0 ? 60.0 : 0.0,
                loggedMealsCount: 3,
                hasConfirmedNutrition: true,
                confirmedKcal: 2150.0
            )
        }

        let snapshot90 = TrendsViewModel.makeSnapshot(rangeDays: 90, records: records90)
        let loader: TrendsDataLoader = { _ in snapshot90 }

        let viewModel = TrendsViewModel(selectedRangeDays: 90, dataLoader: loader)
        await viewModel.load(rangeDays: 90)

        guard let loaded = viewModel.state.value else {
            XCTFail("ViewModel state should have loaded snapshot")
            return
        }

        XCTAssertEqual(loaded.rangeDays, 90)
        XCTAssertEqual(loaded.records.count, 90, "90d loading must build 90 daily records")

        // Sub-window coverage tests:
        // Dynamic TDEE must explicitly label its 14-day window and sample count
        XCTAssertTrue(
            loaded.dynamicTdeeCoverage.contains("14 днів"),
            "Dynamic TDEE must explicitly label 14d window coverage: \(loaded.dynamicTdeeCoverage)"
        )

        // ACWR must explicitly label its 28-day EWMA window and sample count
        XCTAssertTrue(
            loaded.acwrCoverage.contains("28 днів"),
            "ACWR must explicitly label 28d window coverage: \(loaded.acwrCoverage)"
        )

        // Weight coverage must show 90d span and sample count transparently
        XCTAssertTrue(
            loaded.weightCoverage.contains("90 днів"),
            "Weight coverage must show 90d span: \(loaded.weightCoverage)"
        )
        XCTAssertTrue(
            loaded.weightCoverage.contains("замірів"),
            "Weight coverage must display sample count: \(loaded.weightCoverage)"
        )

        // Autonomic coverage must show 90d span and nocturnal samples count
        XCTAssertTrue(
            loaded.autonomicCoverage.contains("90 днів"),
            "Autonomic coverage must show 90d span: \(loaded.autonomicCoverage)"
        )

        // Correlation coverage must reflect complete nutrition sample count
        XCTAssertTrue(
            loaded.correlationCoverage.contains("90 днів"),
            "Correlation coverage must reflect 90d pool: \(loaded.correlationCoverage)"
        )
    }
}
