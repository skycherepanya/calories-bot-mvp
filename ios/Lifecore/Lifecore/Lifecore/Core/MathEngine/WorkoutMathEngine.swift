import Foundation

// MARK: - Split & Lap Models

public struct SplitMetric: Sendable, Codable, Identifiable {
    public var id: Int { km }
    public let km: Int
    public let durationSeconds: Double
    public let paceMinPerKm: Double
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let elevationDiffMeters: Double
    public let avgCadence: Double?

    public init(
        km: Int,
        durationSeconds: Double,
        paceMinPerKm: Double,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        elevationDiffMeters: Double = 0.0,
        avgCadence: Double? = nil
    ) {
        self.km = km
        self.durationSeconds = durationSeconds
        self.paceMinPerKm = paceMinPerKm
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationDiffMeters = elevationDiffMeters
        self.avgCadence = avgCadence
    }

    enum CodingKeys: String, CodingKey {
        case km
        case durationSeconds = "duration_s"
        case paceMinPerKm = "pace_min_km"
        case avgHeartRate = "avg_hr"
        case maxHeartRate = "max_hr"
        case elevationDiffMeters = "elevation_diff_m"
        case avgCadence = "avg_cadence"
    }

    /// Formatted pace string like "5:45/km"
    public var formattedPace: String {
        let minutes = Int(paceMinPerKm)
        let seconds = Int(round((paceMinPerKm - Double(minutes)) * 60.0))
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}

public struct LapIntervalMetric: Sendable, Codable, Identifiable {
    public var id: Int { lapIndex }
    public let lapIndex: Int
    public let lapType: String // "work", "recovery", "warmup", "cooldown"
    public let durationSeconds: Double
    public let distanceMeters: Double?
    public let paceMinPerKm: Double?
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let hrRecoveryDropBpm: Double?

    public init(
        lapIndex: Int,
        lapType: String,
        durationSeconds: Double,
        distanceMeters: Double? = nil,
        paceMinPerKm: Double? = nil,
        avgHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        hrRecoveryDropBpm: Double? = nil
    ) {
        self.lapIndex = lapIndex
        self.lapType = lapType
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.paceMinPerKm = paceMinPerKm
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.hrRecoveryDropBpm = hrRecoveryDropBpm
    }

    enum CodingKeys: String, CodingKey {
        case lapIndex = "lap_index"
        case lapType = "type"
        case durationSeconds = "duration_s"
        case distanceMeters = "distance_m"
        case paceMinPerKm = "avg_pace_min_km"
        case avgHeartRate = "avg_hr"
        case maxHeartRate = "max_hr"
        case hrRecoveryDropBpm = "hr_drop_bpm"
    }
}

public struct BenchmarkDelta: Sendable, Codable {
    public let comparedWorkoutsCount: Int
    public let paceDeltaSecPerKm: Double // negative means faster
    public let hrDeltaBpm: Double // positive means higher HR cost
    public let efDelta: Double // positive means higher efficiency
    public let narrativeSummary: String

    public init(
        comparedWorkoutsCount: Int,
        paceDeltaSecPerKm: Double,
        hrDeltaBpm: Double,
        efDelta: Double,
        narrativeSummary: String
    ) {
        self.comparedWorkoutsCount = comparedWorkoutsCount
        self.paceDeltaSecPerKm = paceDeltaSecPerKm
        self.hrDeltaBpm = hrDeltaBpm
        self.efDelta = efDelta
        self.narrativeSummary = narrativeSummary
    }
}

public struct WorkoutAnalysisResult: Sendable, Codable {
    public let workoutUUID: UUID
    public let workoutType: String
    public let distanceKm: Double
    public let durationMin: Double
    public let avgPaceMinKm: Double
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let elevationGainMeters: Double
    public let efficiencyFactor: Double?
    public let aerobicDecouplingPct: Double?
    public let isIndoorTreadmill: Bool
    public let splits: [SplitMetric]
    public let laps: [LapIntervalMetric]
    public let benchmarkDelta: BenchmarkDelta?

    public init(
        workoutUUID: UUID,
        workoutType: String,
        distanceKm: Double,
        durationMin: Double,
        avgPaceMinKm: Double,
        avgHeartRate: Double?,
        maxHeartRate: Double?,
        elevationGainMeters: Double,
        efficiencyFactor: Double?,
        aerobicDecouplingPct: Double?,
        isIndoorTreadmill: Bool,
        splits: [SplitMetric],
        laps: [LapIntervalMetric],
        benchmarkDelta: BenchmarkDelta? = nil
    ) {
        self.workoutUUID = workoutUUID
        self.workoutType = workoutType
        self.distanceKm = distanceKm
        self.durationMin = durationMin
        self.avgPaceMinKm = avgPaceMinKm
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationGainMeters = elevationGainMeters
        self.efficiencyFactor = efficiencyFactor
        self.aerobicDecouplingPct = aerobicDecouplingPct
        self.isIndoorTreadmill = isIndoorTreadmill
        self.splits = splits
        self.laps = laps
        self.benchmarkDelta = benchmarkDelta
    }
}

// MARK: - Workout Math Engine

public enum WorkoutMathEngine {

    /// Slices raw telemetry stream into 1-kilometer incremental splits with linear boundary interpolation.
    public static func computeKilometerSplits(from samples: [RawTelemetryPoint]) -> [SplitMetric] {
        guard samples.count >= 2 else { return [] }
        guard let firstSample = samples.first, let lastSample = samples.last else { return [] }

        let totalDistance = lastSample.distanceMeters
        guard totalDistance >= 500.0 else {
            // Under 500m - not enough continuous distance for meaningful splits
            return []
        }

        var splits: [SplitMetric] = []
        var previousTargetMeters = 0.0
        var previousTargetDate = firstSample.timestamp
        var currentKmIndex = 1

        let totalKmTargets = Int(floor(totalDistance / 1000.0))

        // 1. Calculate each full 1.0 km split using linear interpolation
        for km in 1...max(1, totalKmTargets) {
            let targetMeters = Double(km) * 1000.0
            guard targetMeters <= totalDistance else { break }

            // Find samples bounding targetMeters
            var targetDate: Date?
            var boundingIndex = 0

            for i in 0..<(samples.count - 1) {
                let p1 = samples[i]
                let p2 = samples[i + 1]

                if p1.distanceMeters <= targetMeters && targetMeters <= p2.distanceMeters {
                    let distDiff = p2.distanceMeters - p1.distanceMeters
                    if distDiff > 0 {
                        let fraction = (targetMeters - p1.distanceMeters) / distDiff
                        let timeDiff = p2.timestamp.timeIntervalSince(p1.timestamp)
                        targetDate = p1.timestamp.addingTimeInterval(fraction * timeDiff)
                    } else {
                        targetDate = p2.timestamp
                    }
                    boundingIndex = i + 1
                    break
                }
            }

            let splitEndDate = targetDate ?? samples[min(boundingIndex, samples.count - 1)].timestamp
            let durationSeconds = max(1.0, splitEndDate.timeIntervalSince(previousTargetDate))
            let distanceMeters = targetMeters - previousTargetMeters // exactly 1000m

            let paceMinPerKm = (durationSeconds / distanceMeters) * (1000.0 / 60.0)

            // Extract heart rate, altitude, cadence for this segment
            let segmentSamples = samples.filter {
                $0.timestamp >= previousTargetDate && $0.timestamp <= splitEndDate
            }
            let hrValues = segmentSamples.compactMap { $0.heartRateBpm }
            let avgHr = hrValues.isEmpty ? nil : (hrValues.reduce(0.0, +) / Double(hrValues.count))
            let maxHr = hrValues.max()

            let startAlt = segmentSamples.first?.altitudeMeters ?? 0.0
            let endAlt = segmentSamples.last?.altitudeMeters ?? 0.0
            let elevationDiff = round((endAlt - startAlt) * 10) / 10

            let cadenceValues = segmentSamples.compactMap { $0.cadenceRpm }
            let avgCadence = cadenceValues.isEmpty ? nil : (cadenceValues.reduce(0.0, +) / Double(cadenceValues.count))

            splits.append(
                SplitMetric(
                    km: currentKmIndex,
                    durationSeconds: round(durationSeconds * 10) / 10,
                    paceMinPerKm: round(paceMinPerKm * 100) / 100,
                    avgHeartRate: avgHr != nil ? round(avgHr! * 10) / 10 : nil,
                    maxHeartRate: maxHr != nil ? round(maxHr! * 10) / 10 : nil,
                    elevationDiffMeters: elevationDiff,
                    avgCadence: avgCadence != nil ? round(avgCadence!) : nil
                )
            )

            previousTargetMeters = targetMeters
            previousTargetDate = splitEndDate
            currentKmIndex += 1
        }

        // 2. Partial final split if remaining distance >= 100m (e.g. 170m on a 4.17km run)
        let remainingDistance = totalDistance - previousTargetMeters
        if remainingDistance >= 100.0 {
            let finalDate = lastSample.timestamp
            let durationSeconds = max(1.0, finalDate.timeIntervalSince(previousTargetDate))
            let paceMinPerKm = (durationSeconds / remainingDistance) * (1000.0 / 60.0)

            let segmentSamples = samples.filter { $0.timestamp >= previousTargetDate }
            let hrValues = segmentSamples.compactMap { $0.heartRateBpm }
            let avgHr = hrValues.isEmpty ? nil : (hrValues.reduce(0.0, +) / Double(hrValues.count))
            let maxHr = hrValues.max()

            let startAlt = segmentSamples.first?.altitudeMeters ?? 0.0
            let endAlt = segmentSamples.last?.altitudeMeters ?? 0.0
            let elevationDiff = round((endAlt - startAlt) * 10) / 10

            let cadenceValues = segmentSamples.compactMap { $0.cadenceRpm }
            let avgCadence = cadenceValues.isEmpty ? nil : (cadenceValues.reduce(0.0, +) / Double(cadenceValues.count))

            splits.append(
                SplitMetric(
                    km: currentKmIndex,
                    durationSeconds: round(durationSeconds * 10) / 10,
                    paceMinPerKm: round(paceMinPerKm * 100) / 100,
                    avgHeartRate: avgHr != nil ? round(avgHr! * 10) / 10 : nil,
                    maxHeartRate: maxHr != nil ? round(maxHr! * 10) / 10 : nil,
                    elevationDiffMeters: elevationDiff,
                    avgCadence: avgCadence != nil ? round(avgCadence!) : nil
                )
            )
        }

        return splits
    }

    /// Computes Efficiency Factor (EF): Speed (m/min) / Average HR (bpm).
    public static func computeEfficiencyFactor(distanceMeters: Double, durationSeconds: Double, avgHeartRate: Double) -> Double? {
        guard durationSeconds > 0, avgHeartRate > 0 else { return nil }
        let durationMinutes = durationSeconds / 60.0
        let speedMetersPerMin = distanceMeters / durationMinutes
        let ef = speedMetersPerMin / avgHeartRate
        return round(ef * 1000) / 1000
    }

    /// Computes Aerobic Decoupling / Cardiac Drift % between the first and second half of a workout.
    /// Formula: ((EF_first_half - EF_second_half) / EF_first_half) * 100
    public static func computeCardiacDrift(splits: [SplitMetric]) -> Double? {
        guard splits.count >= 2 else { return nil }

        let midpoint = splits.count / 2
        let firstHalf = Array(splits[0..<midpoint])
        let secondHalf = Array(splits[midpoint..<splits.count])

        func halfEF(_ halfSplits: [SplitMetric]) -> Double? {
            let totalDistMeters = Double(halfSplits.count) * 1000.0
            let totalDurSeconds = halfSplits.reduce(0.0) { $0 + $1.durationSeconds }
            let validHRs = halfSplits.compactMap { $0.avgHeartRate }
            guard !validHRs.isEmpty, totalDurSeconds > 0 else { return nil }
            let avgHR = validHRs.reduce(0.0, +) / Double(validHRs.count)
            return computeEfficiencyFactor(distanceMeters: totalDistMeters, durationSeconds: totalDurSeconds, avgHeartRate: avgHR)
        }

        guard let ef1 = halfEF(firstHalf), let ef2 = halfEF(secondHalf), ef1 > 0 else {
            return nil
        }

        let decouplingPct = ((ef1 - ef2) / ef1) * 100.0
        return round(decouplingPct * 100) / 100
    }

    /// Analyzes structured intervals from HealthKit interval laps.
    public static func analyzeIntervalLaps(
        rawLaps: [RawIntervalLap],
        samples: [RawTelemetryPoint]
    ) -> [LapIntervalMetric] {
        var result: [LapIntervalMetric] = []

        for (i, lap) in rawLaps.enumerated() {
            let duration = lap.durationSeconds
            let distance = lap.distanceMeters

            var pace: Double? = nil
            if let dist = distance, dist > 0, duration > 0 {
                pace = (duration / dist) * (1000.0 / 60.0)
            }

            // Find telemetry samples within lap window
            let lapEnd = lap.endDate ?? lap.startDate.addingTimeInterval(duration)
            let inLapSamples = samples.filter { $0.timestamp >= lap.startDate && $0.timestamp <= lapEnd }
            let hrList = inLapSamples.compactMap { $0.heartRateBpm }
            let avgHr = hrList.isEmpty ? nil : hrList.reduce(0.0, +) / Double(hrList.count)
            let maxHr = hrList.max()

            // Determine if work or recovery
            // Recovery lap heuristic: very low speed (< 6 km/h) or marked explicitly
            let isRecovery = (pace != nil && pace! > 9.0) || (distance != nil && distance! < 150.0)
            let lapType = isRecovery ? "recovery" : "work"

            // Compute HR recovery drop during rest interval (peak at start - trough at end)
            var hrDrop: Double? = nil
            if isRecovery && hrList.count >= 2 {
                let initialHr = hrList.prefix(3).reduce(0.0, +) / Double(min(3, hrList.count))
                let finalHr = hrList.suffix(3).reduce(0.0, +) / Double(min(3, hrList.count))
                hrDrop = max(0.0, round((initialHr - finalHr) * 10) / 10)
            }

            result.append(
                LapIntervalMetric(
                    lapIndex: i + 1,
                    lapType: lapType,
                    durationSeconds: round(duration * 10) / 10,
                    distanceMeters: distance != nil ? round(distance! * 10) / 10 : nil,
                    paceMinPerKm: pace != nil ? round(pace! * 100) / 100 : nil,
                    avgHeartRate: avgHr != nil ? round(avgHr! * 10) / 10 : nil,
                    maxHeartRate: maxHr != nil ? round(maxHr! * 10) / 10 : nil,
                    hrRecoveryDropBpm: hrDrop
                )
            )
        }

        return result
    }

    /// Evaluates current session against historical sessions within distance tolerance (default +/- 20%).
    public static func computeHistoricalBenchmark(
        current: (distanceKm: Double, paceMinKm: Double, avgHr: Double?, ef: Double?),
        history: [(distanceKm: Double, paceMinKm: Double, avgHr: Double?, ef: Double?)],
        distanceTolerancePct: Double = 0.20
    ) -> BenchmarkDelta? {
        let matching = history.filter { past in
            let diff = abs(past.distanceKm - current.distanceKm) / current.distanceKm
            return diff <= distanceTolerancePct
        }

        guard !matching.isEmpty else { return nil }

        let count = Double(matching.count)
        let benchmarkPace = matching.map { $0.paceMinKm }.reduce(0.0, +) / count
        let validHrs = matching.compactMap { $0.avgHr }
        let benchmarkHr = validHrs.isEmpty ? nil : validHrs.reduce(0.0, +) / Double(validHrs.count)
        let validEfs = matching.compactMap { $0.ef }
        let benchmarkEf = validEfs.isEmpty ? nil : validEfs.reduce(0.0, +) / Double(validEfs.count)

        // Deltas
        let paceDeltaSec = round(((current.paceMinKm - benchmarkPace) * 60.0) * 10) / 10
        let hrDelta = (current.avgHr != nil && benchmarkHr != nil) ? round((current.avgHr! - benchmarkHr!) * 10) / 10 : 0.0
        let efDelta = (current.ef != nil && benchmarkEf != nil) ? round((current.ef! - benchmarkEf!) * 1000) / 1000 : 0.0

        let paceText = paceDeltaSec <= 0
            ? String(format: "%.0f sec/km faster", abs(paceDeltaSec))
            : String(format: "%.0f sec/km slower", paceDeltaSec)

        let hrText = hrDelta <= 0
            ? String(format: "%.0f bpm lower HR cost", abs(hrDelta))
            : String(format: "+%.0f bpm higher HR cost", hrDelta)

        let summary = "Compared to \(matching.count) similar session(s): pace was \(paceText), at \(hrText) (EF delta: \(efDelta >= 0 ? "+" : "")\(efDelta))."

        return BenchmarkDelta(
            comparedWorkoutsCount: matching.count,
            paceDeltaSecPerKm: paceDeltaSec,
            hrDeltaBpm: hrDelta,
            efDelta: efDelta,
            narrativeSummary: summary
        )
    }

    /// Full end-to-end workout telemetry analysis pipeline.
    public static func analyze(
        series: WorkoutTelemetrySeries,
        historicalWorkouts: [(distanceKm: Double, paceMinKm: Double, avgHr: Double?, ef: Double?)] = []
    ) -> WorkoutAnalysisResult {
        let totalDistance = series.totalDistanceMeters ?? series.samples.last?.distanceMeters ?? 0.0
        let totalDuration = max(1.0, series.totalDurationSeconds)
        let distanceKm = round((totalDistance / 1000.0) * 100) / 100
        let durationMin = round((totalDuration / 60.0) * 10) / 10

        let avgPaceMinKm: Double
        if totalDistance > 0 {
            avgPaceMinKm = round(((totalDuration / totalDistance) * (1000.0 / 60.0)) * 100) / 100
        } else {
            avgPaceMinKm = 0.0
        }

        let allHrs = series.samples.compactMap { $0.heartRateBpm }
        let avgHr = allHrs.isEmpty ? nil : round((allHrs.reduce(0.0, +) / Double(allHrs.count)) * 10) / 10
        let maxHr = allHrs.max()

        // 1km splits
        let splits = computeKilometerSplits(from: series.samples)

        // Elevation gain from splits
        let elevationGain = splits.map { max(0.0, $0.elevationDiffMeters) }.reduce(0.0, +)

        // Efficiency Factor
        let ef: Double?
        if let hr = avgHr, totalDistance > 0 {
            ef = computeEfficiencyFactor(distanceMeters: totalDistance, durationSeconds: totalDuration, avgHeartRate: hr)
        } else {
            ef = nil
        }

        // Aerobic Decoupling
        let decouplingPct = computeCardiacDrift(splits: splits)

        // Interval laps
        let laps = analyzeIntervalLaps(rawLaps: series.intervalActivities, samples: series.samples)

        // Detect indoor treadmill
        let isIndoor = series.isIndoor || (elevationGain == 0.0 && distanceKm > 1.0 && series.workoutType == "running")

        // Benchmark comparison
        let benchmark = computeHistoricalBenchmark(
            current: (distanceKm: distanceKm, paceMinKm: avgPaceMinKm, avgHr: avgHr, ef: ef),
            history: historicalWorkouts
        )

        return WorkoutAnalysisResult(
            workoutUUID: series.workoutUUID,
            workoutType: series.workoutType,
            distanceKm: distanceKm,
            durationMin: durationMin,
            avgPaceMinKm: avgPaceMinKm,
            avgHeartRate: avgHr,
            maxHeartRate: maxHr,
            elevationGainMeters: round(elevationGain * 10) / 10,
            efficiencyFactor: ef,
            aerobicDecouplingPct: decouplingPct,
            isIndoorTreadmill: isIndoor,
            splits: splits,
            laps: laps,
            benchmarkDelta: benchmark
        )
    }
}
