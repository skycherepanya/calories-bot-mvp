import XCTest
import CoreLocation
@testable import Lifecore

final class WorkoutTelemetryTests: XCTestCase {

    // MARK: - 1. Workout Start t0 Split Timing (Audit F13 & Spec)

    func testStartingPointT0SplitDuration_zeroAnchored() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // 10 increments of 100m at 36s each, with an explicit t0 anchor at 0m (11 samples total)
        let samples = (0...10).map { i in
            RawTelemetryPoint(
                timestamp: t0.addingTimeInterval(Double(i * 36)),
                distanceMeters: Double(i * 100),
                heartRateBpm: 140,
                altitudeMeters: nil
            )
        }

        let splits = WorkoutMathEngine.computeKilometerSplits(from: samples)
        XCTAssertEqual(splits.count, 1)

        let split = splits[0]
        XCTAssertEqual(split.km, 1)
        XCTAssertEqual(split.durationSeconds, 360.0, accuracy: 0.001, "First km must account for the full 360s elapsed time from t0")
        XCTAssertEqual(split.paceMinPerKm, 6.0, accuracy: 0.001, "1000m in 360s must yield exact 6.0 min/km pace")
        XCTAssertEqual(split.startDate, t0, "Split must preserve segment start timestamp t0")
    }

    func testStartingPointT0SplitDuration_endPointOnlyStream() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // 10 increments of 100m at 36s each, as delivered by HealthKit end-point-only streams (10 samples, starting at 100m/36s)
        let samples = (1...10).map { i in
            RawTelemetryPoint(
                timestamp: t0.addingTimeInterval(Double(i * 36)),
                distanceMeters: Double(i * 100),
                heartRateBpm: 145,
                altitudeMeters: nil
            )
        }

        // Without passing workoutStartDate explicitly, the engine infers t0 backwards from the first increment rate
        let splitsInferred = WorkoutMathEngine.computeKilometerSplits(from: samples)
        XCTAssertEqual(splitsInferred.count, 1)
        XCTAssertEqual(splitsInferred[0].durationSeconds, 360.0, accuracy: 0.001, "End-point-only stream must not drop the initial 36s segment (expected 360s, not 324s)")
        XCTAssertEqual(splitsInferred[0].paceMinPerKm, 6.0, accuracy: 0.001, "Pace must be 6.0 min/km, not 5.4 min/km")

        // With explicit workoutStartDate t0 passed
        let splitsExplicit = WorkoutMathEngine.computeKilometerSplits(from: samples, workoutStartDate: t0)
        XCTAssertEqual(splitsExplicit.count, 1)
        XCTAssertEqual(splitsExplicit[0].durationSeconds, 360.0, accuracy: 0.001)
        XCTAssertEqual(splitsExplicit[0].paceMinPerKm, 6.0, accuracy: 0.001)
        XCTAssertEqual(splitsExplicit[0].startDate, t0)
    }

    // MARK: - 2. Partial Final Kilometer Pace Interpolation

    func testPartialFinalKilometerPaceInterpolation() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var samples: [RawTelemetryPoint] = [
            RawTelemetryPoint(timestamp: t0, distanceMeters: 0.0, heartRateBpm: 140)
        ]

        // Km 1: 1000m in 360s (pace 6.0 min/km)
        for i in 1...10 {
            samples.append(
                RawTelemetryPoint(
                    timestamp: t0.addingTimeInterval(Double(i * 36)),
                    distanceMeters: Double(i * 100),
                    heartRateBpm: 140
                )
            )
        }

        // Km 2 (partial): 500m in 150s (pace 5.0 min/km)
        let tKm1 = t0.addingTimeInterval(360)
        for i in 1...5 {
            samples.append(
                RawTelemetryPoint(
                    timestamp: tKm1.addingTimeInterval(Double(i * 30)),
                    distanceMeters: 1000.0 + Double(i * 100),
                    heartRateBpm: 155
                )
            )
        }

        let splits = WorkoutMathEngine.computeKilometerSplits(from: samples)
        XCTAssertEqual(splits.count, 2, "Expected 1 full km split and 1 partial final km split")

        let km1 = splits[0]
        XCTAssertEqual(km1.km, 1)
        XCTAssertEqual(km1.durationSeconds, 360.0, accuracy: 0.1)
        XCTAssertEqual(km1.paceMinPerKm, 6.00, accuracy: 0.01)

        let km2 = splits[1]
        XCTAssertEqual(km2.km, 2)
        XCTAssertEqual(km2.durationSeconds, 150.0, accuracy: 0.1, "Partial split duration must be exactly 150s for the remaining 500m")
        XCTAssertEqual(km2.paceMinPerKm, 5.00, accuracy: 0.01, "Partial split pace must interpolate to 5.00 min/km ((150s / 500m) * 1000 / 60)")
        XCTAssertEqual(km2.startDate, tKm1, "Partial split startDate must match the end timestamp of km 1")
    }

    // MARK: - 3. Elevation Preservation & Treadmill Detection (Audit F14)

    func testMissingElevationGainRemainsNil() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = (0...10).map { i in
            RawTelemetryPoint(
                timestamp: t0.addingTimeInterval(Double(i * 36)),
                distanceMeters: Double(i * 100),
                heartRateBpm: 140,
                altitudeMeters: nil // GPS altitude missing / unavailable
            )
        }

        let series = WorkoutTelemetrySeries(
            workoutUUID: UUID(),
            workoutType: "running",
            startDate: t0,
            endDate: t0.addingTimeInterval(360),
            totalDurationSeconds: 360,
            totalDistanceMeters: 1000,
            totalActiveCalories: 80,
            samples: samples,
            intervalActivities: [],
            isIndoor: false
        )

        let analysis = WorkoutMathEngine.analyze(series: series)

        // Must preserve missing elevation gain as nil, NOT default to 0.0m
        XCTAssertNil(analysis.elevationGainMeters, "Missing GPS altitude must result in nil elevationGainMeters")

        // Audit F14: Zero / missing elevation must NOT convert outdoor run to treadmill
        XCTAssertFalse(analysis.isIndoorTreadmill, "Outdoor running with missing elevation must remain isIndoorTreadmill = false")
    }

    func testFlatOutdoorRunningIsNotTreadmill() throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // 5 km outdoor run on completely flat terrain (constant 45.0m altitude -> 0.0m gain)
        let samples = (0...50).map { i in
            RawTelemetryPoint(
                timestamp: t0.addingTimeInterval(Double(i * 36)),
                distanceMeters: Double(i * 100),
                heartRateBpm: 142,
                altitudeMeters: 45.0
            )
        }

        let series = WorkoutTelemetrySeries(
            workoutUUID: UUID(),
            workoutType: "running",
            startDate: t0,
            endDate: t0.addingTimeInterval(1800),
            totalDurationSeconds: 1800,
            totalDistanceMeters: 5000,
            totalActiveCalories: 400,
            samples: samples,
            intervalActivities: [],
            isIndoor: false // Explicitly outdoor
        )

        let analysis = WorkoutMathEngine.analyze(series: series)

        let elev = try XCTUnwrap(analysis.elevationGainMeters)
        XCTAssertEqual(elev, 0.0, accuracy: 0.1)
        // Audit F14 regression check
        XCTAssertFalse(analysis.isIndoorTreadmill, "Flat outdoor run must never be classified as indoor treadmill")
    }

    func testExplicitIndoorWorkoutPreservesIndoorTreadmill() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = (0...10).map { i in
            RawTelemetryPoint(
                timestamp: t0.addingTimeInterval(Double(i * 36)),
                distanceMeters: Double(i * 100),
                heartRateBpm: 140,
                altitudeMeters: nil
            )
        }

        let series = WorkoutTelemetrySeries(
            workoutUUID: UUID(),
            workoutType: "running",
            startDate: t0,
            endDate: t0.addingTimeInterval(360),
            totalDurationSeconds: 360,
            totalDistanceMeters: 1000,
            totalActiveCalories: 80,
            samples: samples,
            intervalActivities: [],
            isIndoor: true // Explicitly indoor
        )

        let analysis = WorkoutMathEngine.analyze(series: series)
        XCTAssertTrue(analysis.isIndoorTreadmill, "Workout marked isIndoor: true must evaluate to isIndoorTreadmill = true")
    }

    func testPositiveElevationGainCalculation() throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Rolling terrain: 100m -> 110m (+10) -> 105m (-5) -> 125m (+20). Total gain = 30m.
        let altitudes = [100.0, 105.0, 110.0, 107.0, 105.0, 115.0, 125.0]
        let samples = altitudes.enumerated().map { i, alt in
            RawTelemetryPoint(
                timestamp: t0.addingTimeInterval(Double(i * 60)),
                distanceMeters: Double(i * 200),
                heartRateBpm: 150,
                altitudeMeters: alt
            )
        }

        let series = WorkoutTelemetrySeries(
            workoutUUID: UUID(),
            workoutType: "running",
            startDate: t0,
            endDate: t0.addingTimeInterval(360),
            totalDurationSeconds: 360,
            totalDistanceMeters: 1200,
            totalActiveCalories: 100,
            samples: samples,
            intervalActivities: [],
            isIndoor: false
        )

        let analysis = WorkoutMathEngine.analyze(series: series)
        let gain = try XCTUnwrap(analysis.elevationGainMeters)
        XCTAssertEqual(gain, 30.0, accuracy: 0.1, "Total elevation gain should sum only positive upward deltas (10m + 20m = 30m)")
    }

    // MARK: - 4. Realistic GPS Accuracy Filtering

    func testRealisticGPSAccuracyFiltering() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        // Valid location 1
        let loc1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 47.4979, longitude: 19.0402),
            altitude: 120.0,
            horizontalAccuracy: 8.0,
            verticalAccuracy: 12.0,
            timestamp: t0
        )

        // Invalid signal: negative horizontal accuracy
        let loc2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 47.4980, longitude: 19.0403),
            altitude: 121.0,
            horizontalAccuracy: -1.0,
            verticalAccuracy: 10.0,
            timestamp: t0.addingTimeInterval(5)
        )

        // Excessive horizontal drift (> 50m)
        let loc3 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 47.4981, longitude: 19.0404),
            altitude: 122.0,
            horizontalAccuracy: 75.0,
            verticalAccuracy: 15.0,
            timestamp: t0.addingTimeInterval(10)
        )

        // Invalid signal: negative vertical accuracy
        let loc4 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 47.4982, longitude: 19.0405),
            altitude: 123.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: -1.0,
            timestamp: t0.addingTimeInterval(15)
        )

        // Excessive vertical drift (> 35m)
        let loc5 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 47.4983, longitude: 19.0406),
            altitude: 124.0,
            horizontalAccuracy: 12.0,
            verticalAccuracy: 55.0,
            timestamp: t0.addingTimeInterval(20)
        )

        // Valid location 2
        let loc6 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 47.4984, longitude: 19.0407),
            altitude: 135.0,
            horizontalAccuracy: 15.0,
            verticalAccuracy: 20.0,
            timestamp: t0.addingTimeInterval(25)
        )

        let filtered = WorkoutTelemetryExtractor.filterLocations([loc1, loc2, loc3, loc4, loc5, loc6])
        XCTAssertEqual(filtered.count, 2, "Only loc1 and loc6 have realistic horizontal (<=50m) and vertical (<=35m) accuracy")
        XCTAssertEqual(filtered[0].altitude, 120.0)
        XCTAssertEqual(filtered[1].altitude, 135.0)

        // Test altitude matching within tolerance window
        let matchedAlt1 = WorkoutTelemetryExtractor.findClosestAltitude(at: t0.addingTimeInterval(2), in: filtered, windowSeconds: 5.0)
        XCTAssertEqual(matchedAlt1, 120.0)

        // Outside window returns nil
        let matchedAltNone = WorkoutTelemetryExtractor.findClosestAltitude(at: t0.addingTimeInterval(60), in: filtered, windowSeconds: 5.0)
        XCTAssertNil(matchedAltNone)
    }

    // MARK: - 5. Structured Interval Laps (No Dropped Laps)

    func testIntervalLapsExtractionWithoutDroppedLaps() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        // 4 interval laps:
        // Lap 1: 400m work lap in 90s (pace 3:45 / km = 3.75 min/km)
        // Lap 2: Stationary recovery lap 60s, distance nil, HR recovery drop
        // Lap 3: 400m work lap in 88s
        // Lap 4: Recovery jog lap 200m in 120s (pace 10.0 min/km)
        let rawLaps: [RawIntervalLap] = [
            RawIntervalLap(lapIndex: 1, startDate: t0, endDate: t0.addingTimeInterval(90), durationSeconds: 90, distanceMeters: 400, activeCalories: 25),
            RawIntervalLap(lapIndex: 2, startDate: t0.addingTimeInterval(90), endDate: t0.addingTimeInterval(150), durationSeconds: 60, distanceMeters: nil, activeCalories: 5),
            RawIntervalLap(lapIndex: 3, startDate: t0.addingTimeInterval(150), endDate: t0.addingTimeInterval(238), durationSeconds: 88, distanceMeters: 400, activeCalories: 26),
            RawIntervalLap(lapIndex: 4, startDate: t0.addingTimeInterval(238), endDate: t0.addingTimeInterval(358), durationSeconds: 120, distanceMeters: 200, activeCalories: 15)
        ]

        // Heart rate samples spanning across the intervals
        var samples: [RawTelemetryPoint] = []
        // Lap 1 HR (rising to 170)
        samples.append(RawTelemetryPoint(timestamp: t0, distanceMeters: 0, heartRateBpm: 150))
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(45), distanceMeters: 200, heartRateBpm: 165))
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(90), distanceMeters: 400, heartRateBpm: 172))

        // Lap 2 HR (recovery drop from 172 to 135)
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(100), distanceMeters: 400, heartRateBpm: 170))
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(120), distanceMeters: 400, heartRateBpm: 150))
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(150), distanceMeters: 400, heartRateBpm: 135))

        // Lap 3 HR (rising to 175)
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(190), distanceMeters: 600, heartRateBpm: 168))
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(238), distanceMeters: 800, heartRateBpm: 175))

        // Lap 4 HR (recovery drop from 175 to 142)
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(250), distanceMeters: 850, heartRateBpm: 172))
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(300), distanceMeters: 920, heartRateBpm: 155))
        samples.append(RawTelemetryPoint(timestamp: t0.addingTimeInterval(358), distanceMeters: 1000, heartRateBpm: 142))

        let analyzedLaps = WorkoutMathEngine.analyzeIntervalLaps(rawLaps: rawLaps, samples: samples)

        XCTAssertEqual(analyzedLaps.count, 4, "Every raw lap must be preserved without any dropped laps")

        // Lap 1: Work
        XCTAssertEqual(analyzedLaps[0].lapIndex, 1)
        XCTAssertEqual(analyzedLaps[0].lapType, "work")
        XCTAssertEqual(analyzedLaps[0].durationSeconds, 90.0)
        XCTAssertEqual(analyzedLaps[0].paceMinPerKm!, 3.75, accuracy: 0.05)
        XCTAssertNotNil(analyzedLaps[0].avgHeartRate)

        // Lap 2: Recovery (stationary rest with distance = nil)
        XCTAssertEqual(analyzedLaps[1].lapIndex, 2)
        XCTAssertEqual(analyzedLaps[1].lapType, "recovery")
        XCTAssertEqual(analyzedLaps[1].durationSeconds, 60.0)
        XCTAssertNotNil(analyzedLaps[1].hrRecoveryDropBpm, "Recovery lap with HR samples must compute hrRecoveryDropBpm")
        XCTAssertGreaterThan(analyzedLaps[1].hrRecoveryDropBpm ?? 0, 20.0, "HR drop should reflect decrease from 170 to 135 bpm")

        // Lap 3: Work
        XCTAssertEqual(analyzedLaps[2].lapIndex, 3)
        XCTAssertEqual(analyzedLaps[2].lapType, "work")
        XCTAssertEqual(analyzedLaps[2].durationSeconds, 88.0)

        // Lap 4: Recovery (pace > 9.0 min/km)
        XCTAssertEqual(analyzedLaps[3].lapIndex, 4)
        XCTAssertEqual(analyzedLaps[3].lapType, "recovery")
        XCTAssertEqual(analyzedLaps[3].durationSeconds, 120.0)
        XCTAssertEqual(analyzedLaps[3].paceMinPerKm!, 10.0, accuracy: 0.05)
        XCTAssertNotNil(analyzedLaps[3].hrRecoveryDropBpm)
    }
}
