import Foundation
import HealthKit

public struct RawSleepSegment: Sendable, Equatable {
    public let interval: DateInterval
    public let stage: SleepStage
    public let sourcePriority: Int
    public let sourceBundleID: String?

    public init(
        interval: DateInterval,
        stage: SleepStage,
        sourcePriority: Int = 10,
        sourceBundleID: String? = nil
    ) {
        self.interval = interval
        self.stage = stage
        self.sourcePriority = sourcePriority
        self.sourceBundleID = sourceBundleID
    }
}

public final class SleepEpisodeReader: Sendable {
    private let healthStore: HKHealthStore

    public init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - HealthKit Query Entry Point

    public func readSleepEpisode(endingBefore date: Date) async throws -> SleepEpisode? {
        guard isAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }

        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .hour, value: -36, to: date) ?? date.addingTimeInterval(-36 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: date, options: .strictEndDate)
        let sleepType = HKCategoryType(.sleepAnalysis)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        // Filter out inBed samples (inBed is value 0, not a sleep stage)
        let rawSegments: [RawSleepSegment] = samples.compactMap { sample in
            guard let stage = Self.mapCategoryValueToStage(sample.value) else { return nil }
            let prio = Self.sourcePriority(for: sample)
            let bundleId = sample.sourceRevision.source.bundleIdentifier
            let interval = DateInterval(start: sample.startDate, end: sample.endDate)
            guard interval.duration > 0 else { return nil }
            return RawSleepSegment(
                interval: interval,
                stage: stage,
                sourcePriority: prio,
                sourceBundleID: bundleId
            )
        }

        guard !rawSegments.isEmpty else { return nil }

        // Cluster segments by proximity (gap <= 2.5 hours belongs to the same sleep episode)
        let clusters = Self.clusterSegments(rawSegments, maxGapSeconds: 2.5 * 3600)
        // Pick the latest cluster ending before the target date
        guard let latestCluster = clusters.last, !latestCluster.isEmpty else { return nil }

        let (stages, totalDuration, episodeIntervalOpt) = Self.deduplicateAndUnion(segments: latestCluster)
        guard let episodeInterval = episodeIntervalOpt, totalDuration > 0 else { return nil }

        // Query nocturnal vitals strictly bounded to episodeInterval
        let boundedPredicate = HKQuery.predicateForSamples(
            withStart: episodeInterval.start,
            end: episodeInterval.end,
            options: []
        )

        // 1. HRV: First try beat-to-beat RMSSD, then SDNN
        var hrvObs: Observation<Double>? = nil
        var hrvMethod: HRVMethod? = nil

        if let cleanRmssd = await fetchNightlyRMSSD(boundedPredicate: boundedPredicate) {
            hrvObs = Observation<Double>(
                value: round(cleanRmssd.value * 10) / 10,
                unit: "ms (RMSSD)",
                observedAt: cleanRmssd.date,
                source: .healthKit,
                quality: .measured,
                observedCount: 1,
                expectedCount: 1
            )
            hrvMethod = .rmssd
        } else if let sdnnSample = await fetchLatestSample(for: HKQuantityType(.heartRateVariabilitySDNN), predicate: boundedPredicate) {
            let sdnn = sdnnSample.quantity.doubleValue(for: .secondUnit(with: .milli))
            hrvObs = Observation<Double>(
                value: round(sdnn * 10) / 10,
                unit: "ms (SDNN)",
                observedAt: sdnnSample.startDate,
                source: .healthKit,
                quality: .measured,
                observedCount: 1,
                expectedCount: 1
            )
            hrvMethod = .sdnn
        }

        // 2. Resting Heart Rate
        var rhrObs: Observation<Double>? = nil
        if let rhrSample = await fetchLatestSample(for: HKQuantityType(.restingHeartRate), predicate: boundedPredicate) {
            let rhr = rhrSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            rhrObs = Observation<Double>(
                value: round(rhr * 10) / 10,
                unit: "bpm",
                observedAt: rhrSample.startDate,
                source: .healthKit,
                quality: .measured,
                observedCount: 1,
                expectedCount: 1
            )
        }

        // 3. Sleeping Wrist Temperature Delta
        var wristTempObs: Observation<Double>? = nil
        if let tempSample = await fetchLatestSample(for: HKQuantityType(.appleSleepingWristTemperature), predicate: boundedPredicate) {
            let delta = tempSample.quantity.doubleValue(for: .degreeCelsius())
            wristTempObs = Observation<Double>(
                value: round(delta * 100) / 100,
                unit: "°C",
                observedAt: tempSample.startDate,
                source: .healthKit,
                quality: .measured,
                observedCount: 1,
                expectedCount: 1
            )
        }

        // 4. Respiratory Rate
        var respObs: Observation<Double>? = nil
        let respSamples = await fetchAllSamples(for: HKQuantityType(.respiratoryRate), predicate: boundedPredicate)
        if !respSamples.isEmpty {
            let unit = HKUnit.count().unitDivided(by: .minute())
            let values = respSamples.map { $0.quantity.doubleValue(for: unit) }
            let avgResp = values.reduce(0.0, +) / Double(values.count)
            respObs = Observation<Double>(
                value: round(avgResp * 10) / 10,
                unit: "br/min",
                observedAt: respSamples.first?.startDate,
                source: .healthKit,
                quality: .measured,
                observedCount: respSamples.count,
                expectedCount: nil
            )
        }

        // 5. Oxygen Saturation (SpO2)
        var spo2Obs: Observation<Double>? = nil
        let spo2Samples = await fetchAllSamples(for: HKQuantityType(.oxygenSaturation), predicate: boundedPredicate)
        if !spo2Samples.isEmpty {
            let unit = HKUnit.percent()
            let values = spo2Samples.map { $0.quantity.doubleValue(for: unit) * 100.0 }
            let avgSpo2 = values.reduce(0.0, +) / Double(values.count)
            spo2Obs = Observation<Double>(
                value: round(avgSpo2 * 10) / 10,
                unit: "%",
                observedAt: spo2Samples.first?.startDate,
                source: .healthKit,
                quality: .measured,
                observedCount: spo2Samples.count,
                expectedCount: nil
            )
        }

        return SleepEpisode(
            interval: episodeInterval,
            stages: stages,
            totalSleepDurationSeconds: totalDuration,
            hrv: hrvObs,
            hrvMethod: hrvMethod,
            restingHeartRate: rhrObs,
            wristTemperatureDeltaCelsius: wristTempObs,
            respiratoryRate: respObs,
            oxygenSaturation: spo2Obs
        )
    }

    // MARK: - Deduplication & Interval Union Algorithm

    /// Merges and dedupes overlapping sleep segments using source precedence and interval union.
    /// Handles `.asleepUnspecified` correctly in total duration without inventing stages.
    public static func deduplicateAndUnion(segments: [RawSleepSegment]) -> (stages: [SleepStageSegment], totalSleepDurationSeconds: TimeInterval, episodeInterval: DateInterval?) {
        let valid = segments.filter { $0.interval.duration > 0 }
        guard !valid.isEmpty else { return ([], 0, nil) }

        let minStart = valid.map(\.interval.start).min()!
        let maxEnd = valid.map(\.interval.end).max()!
        let episodeInterval = DateInterval(start: minStart, end: maxEnd)

        // Collect all slice boundaries
        var boundarySet = Set<Date>()
        for seg in valid {
            boundarySet.insert(seg.interval.start)
            boundarySet.insert(seg.interval.end)
        }
        let boundaries = Array(boundarySet).sorted()
        guard boundaries.count >= 2 else { return ([], 0, nil) }

        var slicedStages: [SleepStageSegment] = []

        for i in 0..<(boundaries.count - 1) {
            let sliceStart = boundaries[i]
            let sliceEnd = boundaries[i + 1]
            guard sliceEnd > sliceStart else { continue }
            let sliceMid = sliceStart.addingTimeInterval(sliceEnd.timeIntervalSince(sliceStart) / 2.0)

            // Find all segments covering this slice
            let matching = valid.filter { $0.interval.start <= sliceMid && sliceMid < $0.interval.end }
            guard !matching.isEmpty else { continue }

            // Pick winner according to source precedence:
            // 1. Highest sourcePriority
            // 2. Specific staged sleep over unspecified
            // 3. Stage preference
            let winner = matching.max { a, b in
                if a.sourcePriority != b.sourcePriority {
                    return a.sourcePriority < b.sourcePriority
                }
                // If same priority, prefer specific stages over unspecified
                let aIsSpecific = (a.stage != .unspecified)
                let bIsSpecific = (b.stage != .unspecified)
                if aIsSpecific != bIsSpecific {
                    return !aIsSpecific // false < true, so b wins if b is specific
                }
                return stagePrecedenceRank(a.stage) < stagePrecedenceRank(b.stage)
            }!

            let sliceInterval = DateInterval(start: sliceStart, end: sliceEnd)
            slicedStages.append(SleepStageSegment(interval: sliceInterval, stage: winner.stage, source: .healthKit))
        }

        // Merge adjacent continuous slices with the same stage
        var mergedStages: [SleepStageSegment] = []
        for stageSeg in slicedStages {
            if let last = mergedStages.last, last.stage == stageSeg.stage, last.interval.end == stageSeg.interval.start {
                let combinedInterval = DateInterval(start: last.interval.start, end: stageSeg.interval.end)
                mergedStages[mergedStages.count - 1] = SleepStageSegment(interval: combinedInterval, stage: last.stage, source: last.source)
            } else {
                mergedStages.append(stageSeg)
            }
        }

        // Compute totalSleepDurationSeconds: union of all non-awake sleep segments
        // Merged stages are mutually disjoint by construction.
        let totalSleepSec = mergedStages.filter { $0.stage != .awake }.reduce(0.0) { $0 + $1.interval.duration }

        return (mergedStages, totalSleepSec, episodeInterval)
    }

    /// Assembles an episode directly from segments and optional observations (for testing / manual construction)
    public static func assembleEpisode(
        segments: [RawSleepSegment],
        hrv: Observation<Double>? = nil,
        hrvMethod: HRVMethod? = nil,
        restingHeartRate: Observation<Double>? = nil,
        wristTemperatureDeltaCelsius: Observation<Double>? = nil,
        respiratoryRate: Observation<Double>? = nil,
        oxygenSaturation: Observation<Double>? = nil
    ) -> SleepEpisode? {
        let (stages, totalDuration, episodeIntervalOpt) = deduplicateAndUnion(segments: segments)
        guard let episodeInterval = episodeIntervalOpt, totalDuration > 0 else { return nil }

        return SleepEpisode(
            interval: episodeInterval,
            stages: stages,
            totalSleepDurationSeconds: totalDuration,
            hrv: hrv,
            hrvMethod: hrvMethod,
            restingHeartRate: restingHeartRate,
            wristTemperatureDeltaCelsius: wristTemperatureDeltaCelsius,
            respiratoryRate: respiratoryRate,
            oxygenSaturation: oxygenSaturation
        )
    }

    // MARK: - Private Helpers

    public static func mapCategoryValueToStage(_ rawValue: Int) -> SleepStage? {
        switch rawValue {
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return .awake
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return .core
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return .deep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return .rem
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            return .unspecified
        default:
            return nil
        }
    }

    public static func sourcePriority(for sample: HKCategorySample) -> Int {
        let bundleId = sample.sourceRevision.source.bundleIdentifier.lowercased()
        let deviceModel = sample.device?.model?.lowercased() ?? ""
        let manufacturer = sample.device?.manufacturer?.lowercased() ?? ""

        if deviceModel.contains("watch") || manufacturer.contains("apple") && deviceModel.contains("watch") {
            return 100 // Apple Watch
        } else if bundleId.contains("health") || bundleId.hasPrefix("com.apple.") {
            return 50  // Apple iOS Built-in
        } else {
            return 10  // Third-party phone / app
        }
    }

    private static func stagePrecedenceRank(_ stage: SleepStage) -> Int {
        switch stage {
        case .deep: return 4
        case .rem: return 3
        case .core: return 2
        case .awake: return 1
        case .unspecified: return 0
        }
    }

    private static func clusterSegments(_ segments: [RawSleepSegment], maxGapSeconds: TimeInterval) -> [[RawSleepSegment]] {
        let sorted = segments.sorted { $0.interval.start < $1.interval.start }
        var clusters: [[RawSleepSegment]] = []
        var currentCluster: [RawSleepSegment] = []
        var clusterEnd: Date? = nil

        for seg in sorted {
            if let end = clusterEnd {
                let gap = seg.interval.start.timeIntervalSince(end)
                if gap > maxGapSeconds {
                    clusters.append(currentCluster)
                    currentCluster = [seg]
                    clusterEnd = seg.interval.end
                } else {
                    currentCluster.append(seg)
                    clusterEnd = max(end, seg.interval.end)
                }
            } else {
                currentCluster.append(seg)
                clusterEnd = seg.interval.end
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }
        return clusters
    }

    // MARK: - HealthKit Vitals Queries

    private func fetchLatestSample(for quantityType: HKQuantityType, predicate: NSPredicate) async -> HKQuantitySample? {
        await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample])?.first)
            }
            healthStore.execute(query)
        }
    }

    private func fetchAllSamples(for quantityType: HKQuantityType, predicate: NSPredicate) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchNightlyRMSSD(boundedPredicate: NSPredicate) async -> (value: Double, date: Date)? {
        let sample: HKHeartbeatSeriesSample? = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKSeriesType.heartbeat(),
                predicate: boundedPredicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKHeartbeatSeriesSample])?.first)
            }
            healthStore.execute(query)
        }

        guard let seriesSample = sample else { return nil }

        return await withCheckedContinuation { continuation in
            var beats: [(timeSinceStart: TimeInterval, precededByGap: Bool)] = []
            let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: seriesSample) { _, timeSinceStart, precededByGap, done, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                beats.append((timeSinceStart: timeSinceStart, precededByGap: precededByGap))
                if done {
                    if let rmssd = VitalsAndIllnessEngine.computeCleanRMSSD(beats: beats) {
                        continuation.resume(returning: (value: rmssd, date: seriesSample.startDate))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            healthStore.execute(seriesQuery)
        }
    }
}
