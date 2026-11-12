import XCTest
@testable import Lifecore

final class ObservationTests: XCTestCase {

    func testUnavailableObservationHasNilValueAndUnavailableQuality() {
        let obs = Observation<Double>(
            value: nil,
            unit: "bpm",
            observedAt: nil,
            source: .healthKit,
            quality: .unavailable
        )

        XCTAssertNil(obs.value, "Unavailable observation value must be strictly nil")
        XCTAssertEqual(obs.unit, "bpm")
        XCTAssertNil(obs.observedAt)
        XCTAssertEqual(obs.source, .healthKit)
        XCTAssertEqual(obs.quality, .unavailable)
        XCTAssertEqual(obs.observedCount, 1)
        XCTAssertNil(obs.expectedCount)
    }

    func testMeasuredZeroIsDistinctFromMissingOrUnavailable() {
        let measuredZero = Observation<Double>(
            value: 0.0,
            unit: "kcal",
            observedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .user,
            quality: .measured
        )

        let unavailable = Observation<Double>(
            value: nil,
            unit: "kcal",
            observedAt: nil,
            source: .derived,
            quality: .unavailable
        )

        XCTAssertNotNil(measuredZero.value)
        XCTAssertEqual(measuredZero.value, 0.0)
        XCTAssertEqual(measuredZero.quality, .measured)

        XCTAssertNil(unavailable.value)
        XCTAssertEqual(unavailable.quality, .unavailable)
        XCTAssertNotEqual(measuredZero, unavailable)
    }

    func testAggregationPreservesMissingnessWithoutFabricatingZeroes() {
        let obs1 = Observation<Double>(
            value: 100.0,
            unit: "kcal",
            source: .user,
            quality: .measured
        )
        let obs2 = Observation<Double>(
            value: nil,
            unit: "kcal",
            source: .healthKit,
            quality: .unavailable
        )

        let items: [Observation<Double>] = [obs1, obs2]

        // Truthful reducer: missing values must not silently coerce to 0.0
        let valuesOnly = items.compactMap(\.value)
        XCTAssertEqual(valuesOnly, [100.0])

        // When all observations are unavailable, aggregation must yield nil rather than 0
        let allUnavailable: [Observation<Double>] = [obs2]
        let sumOrNil: Double? = allUnavailable.compactMap(\.value).isEmpty
            ? nil
            : allUnavailable.compactMap(\.value).reduce(0, +)
        XCTAssertNil(sumOrNil, "Reducing over unavailable observations must not synthesize 0.0")
    }

    func testEqualityAndHashability() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let obsA = Observation<Int>(
            value: 42,
            unit: "count",
            observedAt: date,
            source: .derived,
            quality: .estimated,
            observedCount: 5,
            expectedCount: 10
        )
        let obsB = Observation<Int>(
            value: 42,
            unit: "count",
            observedAt: date,
            source: .derived,
            quality: .estimated,
            observedCount: 5,
            expectedCount: 10
        )
        let obsC = Observation<Int>(
            value: 43,
            unit: "count",
            observedAt: date,
            source: .derived,
            quality: .estimated,
            observedCount: 5,
            expectedCount: 10
        )

        XCTAssertEqual(obsA, obsB)
        XCTAssertNotEqual(obsA, obsC)
        XCTAssertEqual(obsA.hashValue, obsB.hashValue)
    }

    func testCodableRoundTripForPresentAndNilValues() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let present = Observation<Double>(
            value: 72.5,
            unit: "kg",
            observedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .user,
            quality: .measured,
            observedCount: 1,
            expectedCount: 1
        )
        let dataPresent = try encoder.encode(present)
        let decodedPresent = try decoder.decode(Observation<Double>.self, from: dataPresent)
        XCTAssertEqual(present, decodedPresent)

        let missing = Observation<Double>(
            value: nil,
            unit: "ms",
            observedAt: nil,
            source: .healthKit,
            quality: .unavailable,
            observedCount: 0,
            expectedCount: 7
        )
        let dataMissing = try encoder.encode(missing)
        let decodedMissing = try decoder.decode(Observation<Double>.self, from: dataMissing)
        XCTAssertEqual(missing, decodedMissing)
        XCTAssertNil(decodedMissing.value)
    }

    func testObservationSourceAndDataQualityRawValues() {
        XCTAssertEqual(ObservationSource.healthKit.rawValue, "healthKit")
        XCTAssertEqual(ObservationSource.user.rawValue, "user")
        XCTAssertEqual(ObservationSource.derived.rawValue, "derived")
        XCTAssertEqual(ObservationSource.aiEstimate.rawValue, "aiEstimate")
        XCTAssertEqual(ObservationSource.fixture.rawValue, "fixture")
        XCTAssertEqual(ObservationSource.legacy.rawValue, "legacy")

        XCTAssertEqual(DataQuality.measured.rawValue, "measured")
        XCTAssertEqual(DataQuality.estimated.rawValue, "estimated")
        XCTAssertEqual(DataQuality.stale.rawValue, "stale")
        XCTAssertEqual(DataQuality.unavailable.rawValue, "unavailable")
    }

    func testScreenStateEnumCases() {
        let loading: ScreenState<String> = .loading
        let empty: ScreenState<String> = .empty
        let content: ScreenState<String> = .content("payload", isRefreshing: false, isStale: false)
        let refreshingContent: ScreenState<String> = .content("payload", isRefreshing: true, isStale: false)
        let staleContent: ScreenState<String> = .content("payload", isRefreshing: false, isStale: true)
        let failed: ScreenState<String> = .failed(message: "network error", retained: "cached payload")
        let failedWithoutRetained: ScreenState<String> = .failed(message: "timeout", retained: nil)
        let unavailable: ScreenState<String> = .unavailable(message: "HealthKit permission denied")

        if case .loading = loading {
            // expected
        } else {
            XCTFail("Expected .loading")
        }

        if case .empty = empty {
            // expected
        } else {
            XCTFail("Expected .empty")
        }

        if case let .content(val, isRefreshing, isStale) = content {
            XCTAssertEqual(val, "payload")
            XCTAssertFalse(isRefreshing)
            XCTAssertFalse(isStale)
        } else {
            XCTFail("Expected .content")
        }

        if case let .content(_, isRefreshing, _) = refreshingContent {
            XCTAssertTrue(isRefreshing)
        } else {
            XCTFail("Expected refreshing content")
        }

        if case let .content(_, _, isStale) = staleContent {
            XCTAssertTrue(isStale)
        } else {
            XCTFail("Expected stale content")
        }

        if case let .failed(msg, retained) = failed {
            XCTAssertEqual(msg, "network error")
            XCTAssertEqual(retained, "cached payload")
        } else {
            XCTFail("Expected .failed with retained value")
        }

        if case let .failed(msg, retained) = failedWithoutRetained {
            XCTAssertEqual(msg, "timeout")
            XCTAssertNil(retained)
        } else {
            XCTFail("Expected .failed without retained value")
        }

        if case let .unavailable(msg) = unavailable {
            XCTAssertEqual(msg, "HealthKit permission denied")
        } else {
            XCTFail("Expected .unavailable")
        }
    }

    func testScreenStateEqualityWhenValueIsEquatable() {
        let state1: ScreenState<Int> = .content(10, isRefreshing: false, isStale: false)
        let state2: ScreenState<Int> = .content(10, isRefreshing: false, isStale: false)
        let state3: ScreenState<Int> = .content(20, isRefreshing: false, isStale: false)

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }
}
