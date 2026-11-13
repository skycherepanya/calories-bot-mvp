import XCTest
import HealthKit
@testable import Lifecore

final class HealthRepositoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppEnvironment.current = AppEnvironment.fixture()
    }

    // MARK: - 1. Exact Sample Counts (0, 1, 4, 5) & No Synthetic Fallbacks

    func testWeightHistoryWithVariableSampleCountsReturnsExactCountsWithoutSyntheticFallbacks() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let interval = DateInterval(start: now.addingTimeInterval(-30 * 86400), end: now)

        // 0 samples
        let emptyRepo = FixtureHealthRepository(weightObservations: [])
        let emptyResults = try await emptyRepo.weightHistory(in: interval)
        XCTAssertEqual(emptyResults.count, 0, "0 samples must return exactly 0 observations")

        // 1 sample
        let t1 = now.addingTimeInterval(-5 * 86400)
        let obs1 = Observation<Double>(
            value: 78.2,
            unit: "kg",
            observedAt: t1,
            source: .healthKit,
            quality: .measured
        )
        let oneRepo = FixtureHealthRepository(weightObservations: [obs1])
        let oneResults = try await oneRepo.weightHistory(in: interval)
        XCTAssertEqual(oneResults.count, 1)
        XCTAssertEqual(oneResults.first?.value, 78.2)
        XCTAssertEqual(oneResults.first?.observedAt, t1)

        // 4 samples (previously triggered synthetic fallback)
        let fourObs = (1...4).map { i in
            Observation<Double>(
                value: 78.0 + Double(i) * 0.1,
                unit: "kg",
                observedAt: now.addingTimeInterval(-Double(i * 3) * 86400),
                source: .healthKit,
                quality: .measured
            )
        }
        let fourRepo = FixtureHealthRepository(weightObservations: fourObs)
        let fourResults = try await fourRepo.weightHistory(in: interval)
        XCTAssertEqual(fourResults.count, 4, "4 samples must return exactly 4 observations, never synthetic fallbacks")
        for i in 0..<4 {
            XCTAssertEqual(fourResults[i].value, fourObs.sorted(by: { $0.observedAt! < $1.observedAt! })[i].value)
        }

        // 5 samples
        let fiveObs = (1...5).map { i in
            Observation<Double>(
                value: 78.0 + Double(i) * 0.1,
                unit: "kg",
                observedAt: now.addingTimeInterval(-Double(i * 2) * 86400),
                source: .healthKit,
                quality: .measured
            )
        }
        let fiveRepo = FixtureHealthRepository(weightObservations: fiveObs)
        let fiveResults = try await fiveRepo.weightHistory(in: interval)
        XCTAssertEqual(fiveResults.count, 5, "5 samples must return exactly 5 observations")
    }

    // MARK: - 2. Query Error & Unavailable HealthKit Paths

    func testHealthRepositoryUnavailableHealthKitThrowsNotAvailableOnDevice() async {
        let repo = FixtureHealthRepository(isHealthKitAvailable: false)
        let interval = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        do {
            _ = try await repo.weightHistory(in: interval)
            XCTFail("Expected notAvailableOnDevice error")
        } catch let error as HealthKitError {
            if case .notAvailableOnDevice = error {
                // Expected
            } else {
                XCTFail("Unexpected HealthKitError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        do {
            _ = try await repo.sleepEpisode(endingBefore: Date())
            XCTFail("Expected notAvailableOnDevice error")
        } catch let error as HealthKitError {
            if case .notAvailableOnDevice = error {
                // Expected
            } else {
                XCTFail("Unexpected HealthKitError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testHealthRepositoryQueryErrorThrowsUnderlyingError() async {
        let queryErr = HealthKitError.queryFailed("Permission or database error")
        let repo = FixtureHealthRepository(errorToThrow: queryErr)
        let interval = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())

        do {
            _ = try await repo.weightHistory(in: interval)
            XCTFail("Expected queryFailed error")
        } catch let error as HealthKitError {
            if case .queryFailed(let msg) = error {
                XCTAssertEqual(msg, "Permission or database error")
            } else {
                XCTFail("Unexpected HealthKitError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        do {
            _ = try await repo.sleepEpisode(endingBefore: Date())
            XCTFail("Expected queryFailed error")
        } catch let error as HealthKitError {
            if case .queryFailed(let msg) = error {
                XCTAssertEqual(msg, "Permission or database error")
            } else {
                XCTFail("Unexpected HealthKitError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - 3. Overlapping Sleep Sources Deduplicated Via Interval Union

    func testOverlappingSleepSourcesDeduplicatedViaIntervalUnion() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Source 1 (third-party): 23:00 to 07:00 (8h) as unspecified sleep (priority 10)
        let thirdParty = RawSleepSegment(
            interval: DateInterval(start: t0, end: t0.addingTimeInterval(8 * 3600)),
            stage: .unspecified,
            sourcePriority: 10,
            sourceBundleID: "com.thirdparty.sleep"
        )

        // Source 2 (Apple Watch): 23:30 to 06:30 with detailed stages (priority 100)
        // - 23:30 to 00:30 awake (1h)
        // - 00:30 to 02:30 deep (2h)
        // - 02:30 to 05:00 core (2.5h)
        // - 05:00 to 06:30 rem (1.5h)
        let watchAwake = RawSleepSegment(
            interval: DateInterval(start: t0.addingTimeInterval(1800), end: t0.addingTimeInterval(5400)),
            stage: .awake,
            sourcePriority: 100,
            sourceBundleID: "com.apple.health"
        )
        let watchDeep = RawSleepSegment(
            interval: DateInterval(start: t0.addingTimeInterval(5400), end: t0.addingTimeInterval(12600)),
            stage: .deep,
            sourcePriority: 100,
            sourceBundleID: "com.apple.health"
        )
        let watchCore = RawSleepSegment(
            interval: DateInterval(start: t0.addingTimeInterval(12600), end: t0.addingTimeInterval(21600)),
            stage: .core,
            sourcePriority: 100,
            sourceBundleID: "com.apple.health"
        )
        let watchRem = RawSleepSegment(
            interval: DateInterval(start: t0.addingTimeInterval(21600), end: t0.addingTimeInterval(27000)),
            stage: .rem,
            sourcePriority: 100,
            sourceBundleID: "com.apple.health"
        )

        let segments = [thirdParty, watchAwake, watchDeep, watchCore, watchRem]
        let (stages, totalDuration, episodeInterval) = SleepEpisodeReader.deduplicateAndUnion(segments: segments)

        XCTAssertNotNil(episodeInterval)
        XCTAssertEqual(episodeInterval?.start, t0)
        XCTAssertEqual(episodeInterval?.end, t0.addingTimeInterval(8 * 3600))

        // Total sleep duration:
        // [0..1800]: 30m unspecified = 1800s
        // [1800..5400]: 1h awake = 0s
        // [5400..12600]: 2h deep = 7200s
        // [12600..21600]: 2.5h core = 9000s
        // [21600..27000]: 1.5h rem = 5400s
        // [27000..28800]: 30m unspecified = 1800s
        // Total = 1800 + 7200 + 9000 + 5400 + 1800 = 25200s (7.0 hours)
        XCTAssertEqual(totalDuration, 25200.0, accuracy: 0.1)

        // Verify stage sequence
        XCTAssertEqual(stages.count, 6)
        XCTAssertEqual(stages[0].stage, .unspecified)
        XCTAssertEqual(stages[0].interval.duration, 1800.0, accuracy: 0.1)
        XCTAssertEqual(stages[1].stage, .awake)
        XCTAssertEqual(stages[1].interval.duration, 3600.0, accuracy: 0.1)
        XCTAssertEqual(stages[2].stage, .deep)
        XCTAssertEqual(stages[2].interval.duration, 7200.0, accuracy: 0.1)
        XCTAssertEqual(stages[3].stage, .core)
        XCTAssertEqual(stages[3].interval.duration, 9000.0, accuracy: 0.1)
        XCTAssertEqual(stages[4].stage, .rem)
        XCTAssertEqual(stages[4].interval.duration, 5400.0, accuracy: 0.1)
        XCTAssertEqual(stages[5].stage, .unspecified)
        XCTAssertEqual(stages[5].interval.duration, 1800.0, accuracy: 0.1)
    }

    func testOverlappingSleepSegmentsSameStageAreMergedProperly() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Sample A: 22:00 to 02:00 (4h) core
        let segA = RawSleepSegment(
            interval: DateInterval(start: t0, end: t0.addingTimeInterval(4 * 3600)),
            stage: .core,
            sourcePriority: 10
        )
        // Sample B: 01:00 to 05:00 (4h) core (overlaps with A between 01:00 and 02:00)
        let segB = RawSleepSegment(
            interval: DateInterval(start: t0.addingTimeInterval(3 * 3600), end: t0.addingTimeInterval(7 * 3600)),
            stage: .core,
            sourcePriority: 10
        )

        let (stages, totalDuration, episodeIntervalOpt) = SleepEpisodeReader.deduplicateAndUnion(segments: [segA, segB])

        guard let episodeInterval = episodeIntervalOpt else {
            XCTFail("Expected non-nil episodeInterval")
            return
        }
        XCTAssertEqual(episodeInterval.duration, 7 * 3600, accuracy: 0.1)
        // Merged contiguous same-stage slices should result in 1 stage segment
        XCTAssertEqual(stages.count, 1)
        XCTAssertEqual(stages[0].stage, .core)
        XCTAssertEqual(stages[0].interval.duration, 7 * 3600, accuracy: 0.1)
        // Total duration must be 7 hours (25,200s), NOT 8 hours (28,800s)
        XCTAssertEqual(totalDuration, 7 * 3600, accuracy: 0.1)
    }

    // MARK: - 4. Unspecified-Only Sleep Without Fabricating Stages

    func testUnspecifiedOnlySleepCountsDurationWithoutInventingStages() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let duration: TimeInterval = 7.5 * 3600 // 27,000s
        let unspecified = RawSleepSegment(
            interval: DateInterval(start: t0, end: t0.addingTimeInterval(duration)),
            stage: .unspecified,
            sourcePriority: 10
        )

        let episode = SleepEpisodeReader.assembleEpisode(segments: [unspecified])
        XCTAssertNotNil(episode)
        guard let episode = episode else { return }

        XCTAssertEqual(episode.totalSleepDurationSeconds, 27000.0, accuracy: 0.1)
        XCTAssertEqual(episode.totalSleepHours, 7.5, accuracy: 0.01)

        // Assert stages array contains ONLY .unspecified
        XCTAssertEqual(episode.stages.count, 1)
        XCTAssertEqual(episode.stages.first?.stage, .unspecified)

        // Assert NO deep, rem, core, or awake stages are invented
        XCTAssertEqual(episode.deepDurationSeconds, 0.0)
        XCTAssertEqual(episode.remDurationSeconds, 0.0)
        XCTAssertEqual(episode.coreDurationSeconds, 0.0)
        XCTAssertEqual(episode.awakeDurationSeconds, 0.0)
        XCTAssertEqual(episode.unspecifiedDurationSeconds, 27000.0, accuracy: 0.1)
    }

    // MARK: - 5. Stale / Missing Vitals Remain Nil

    func testStaleOrMissingVitalsRemainNilAndNeverSubstitutedWithBaselines() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let seg = RawSleepSegment(
            interval: DateInterval(start: t0, end: t0.addingTimeInterval(8 * 3600)),
            stage: .core,
            sourcePriority: 100
        )

        let hrvObs = Observation<Double>(
            value: 94.5,
            unit: "ms (RMSSD)",
            observedAt: t0.addingTimeInterval(7200),
            source: .healthKit,
            quality: .measured
        )

        // Only HRV is present; wrist temperature, RHR, respiratory rate, SpO2 are all nil
        let episode = SleepEpisodeReader.assembleEpisode(
            segments: [seg],
            hrv: hrvObs,
            hrvMethod: .rmssd,
            restingHeartRate: nil,
            wristTemperatureDeltaCelsius: nil,
            respiratoryRate: nil,
            oxygenSaturation: nil
        )

        XCTAssertNotNil(episode)
        guard let episode = episode else { return }

        // HRV is present
        XCTAssertEqual(episode.hrv?.value, 94.5)
        XCTAssertEqual(episode.hrvMethod, .rmssd)

        // Missing pillars MUST remain nil — NEVER substituted with normal baseline
        XCTAssertNil(episode.restingHeartRate, "Missing RHR must stay nil")
        XCTAssertNil(episode.wristTemperatureDeltaCelsius, "Missing wrist temperature must stay nil, not 0.0 or baseline")
        XCTAssertNil(episode.respiratoryRate, "Missing respiratory rate must stay nil")
        XCTAssertNil(episode.oxygenSaturation, "Missing SpO2 must stay nil")
    }

    // MARK: - 6. Method-Tagged HRV (SDNN vs RMSSD Preserved)

    func testMethodTaggedHRVPreservesSDNNVsRMSSD() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let seg = RawSleepSegment(
            interval: DateInterval(start: t0, end: t0.addingTimeInterval(8 * 3600)),
            stage: .core,
            sourcePriority: 100
        )

        // 1. RMSSD Episode
        let rmssdObs = Observation<Double>(
            value: 88.0,
            unit: "ms (RMSSD)",
            observedAt: t0.addingTimeInterval(3600),
            source: .healthKit,
            quality: .measured
        )
        let rmssdEpisode = SleepEpisodeReader.assembleEpisode(
            segments: [seg],
            hrv: rmssdObs,
            hrvMethod: .rmssd
        )
        XCTAssertEqual(rmssdEpisode?.hrvMethod, .rmssd)
        XCTAssertEqual(rmssdEpisode?.hrv?.value, 88.0)
        XCTAssertTrue(rmssdEpisode?.hrv?.unit.contains("RMSSD") == true)

        // 2. SDNN Episode
        let sdnnObs = Observation<Double>(
            value: 65.0,
            unit: "ms (SDNN)",
            observedAt: t0.addingTimeInterval(3600),
            source: .healthKit,
            quality: .measured
        )
        let sdnnEpisode = SleepEpisodeReader.assembleEpisode(
            segments: [seg],
            hrv: sdnnObs,
            hrvMethod: .sdnn
        )
        XCTAssertEqual(sdnnEpisode?.hrvMethod, .sdnn)
        XCTAssertEqual(sdnnEpisode?.hrv?.value, 65.0)
        XCTAssertTrue(sdnnEpisode?.hrv?.unit.contains("SDNN") == true)
        XCTAssertNotEqual(rmssdEpisode?.hrvMethod, sdnnEpisode?.hrvMethod)
    }

    // MARK: - 7. No Synthetic History In HealthKitManager

    func testHealthKitManagerDoesNotSynthesizeFakeDataWhenHistorySparseOrUnavailable() async {
        // In fixture mode, HealthKit is not authorized/available on simulator without real data
        let weights = await HealthKitManager.shared.fetchBodyWeightHistory(days: 30)
        // With HealthKit empty / no samples, it must NOT produce the 30-day fake ~78.4kg curve
        XCTAssertEqual(weights.count, 0, "Sparse or unavailable HealthKit must return empty weight history, not synthetic Sasha baseline")

        let autonomic = await HealthKitManager.shared.fetchAutonomicLongitudinalHistory(days: 30)
        XCTAssertEqual(autonomic.count, 0, "Sparse or unavailable HealthKit must return empty autonomic history, not synthetic curves")

        let ef = await HealthKitManager.shared.fetchAerobicEfficiencyHistory(limit: 15)
        XCTAssertEqual(ef.count, 0, "Sparse or unavailable HealthKit must return empty EF history, not synthetic running curves")
    }
}
