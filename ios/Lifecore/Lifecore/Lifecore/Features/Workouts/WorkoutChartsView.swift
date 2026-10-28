import SwiftUI
import Charts

public enum TelemetryChartTab: String, CaseIterable, Identifiable {
    case heartRate = "Heart Rate"
    case pace = "Pace"
    case elevation = "Elevation"

    public var id: String { rawValue }

    public var titleUk: String {
        switch self {
        case .heartRate: return "Пульс (ЧСС)"
        case .pace: return "Темп"
        case .elevation: return "Висота"
        }
    }

    public var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .pace: return "speedometer"
        case .elevation: return "mountain.2.fill"
        }
    }
}

public struct ChartDataPoint: Identifiable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let elapsedMin: Double
    public let distanceKm: Double
    public let heartRate: Double?
    public let paceMinKm: Double?
    public let altitudeM: Double?
}

public struct WorkoutChartsView: View {
    public let series: WorkoutTelemetrySeries
    public let avgPaceMinKm: Double?
    public let avgHeartRate: Double?

    @State private var selectedTab: TelemetryChartTab = .heartRate
    @State private var selectedDistance: Double?

    public init(
        series: WorkoutTelemetrySeries,
        avgPaceMinKm: Double? = nil,
        avgHeartRate: Double? = nil
    ) {
        self.series = series
        self.avgPaceMinKm = avgPaceMinKm
        self.avgHeartRate = avgHeartRate
    }

    private var chartPoints: [ChartDataPoint] {
        guard !series.samples.isEmpty else { return [] }

        let firstTime = series.samples.first!.timestamp.timeIntervalSince1970
        let totalCount = series.samples.count
        let step = max(1, totalCount / 120) // Cap points for smooth 60fps Swift Charts rendering

        var points: [ChartDataPoint] = []
        var lastValidPace: Double? = avgPaceMinKm

        for i in stride(from: 0, to: totalCount, by: step) {
            let sample = series.samples[i]
            let elapsedMin = max(0, (sample.timestamp.timeIntervalSince1970 - firstTime) / 60.0)
            let distKm = round((sample.distanceMeters / 1000.0) * 100) / 100

            // Estimate local instantaneous pace from neighboring samples
            var currentPace: Double? = nil
            if i + step < totalCount {
                let next = series.samples[i + step]
                let dDistMeters = next.distanceMeters - sample.distanceMeters
                let dTimeSec = next.timestamp.timeIntervalSince(sample.timestamp)
                if dDistMeters > 15 && dTimeSec > 3 {
                    let pace = (dTimeSec / 60.0) / (dDistMeters / 1000.0)
                    if pace >= 2.5 && pace <= 15.0 {
                        currentPace = pace
                        lastValidPace = pace
                    }
                }
            }

            points.append(ChartDataPoint(
                index: i,
                elapsedMin: elapsedMin,
                distanceKm: distKm,
                heartRate: sample.heartRateBpm,
                paceMinKm: currentPace ?? lastValidPace,
                altitudeM: sample.altitudeMeters
            ))
        }

        return points
    }

    private var selectedPoint: ChartDataPoint? {
        guard let dist = selectedDistance else { return nil }
        return chartPoints.min(by: { abs($0.distanceKm - dist) < abs($1.distanceKm - dist) })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header & Segment Picker
            HStack {
                Label("Графіки телеметрії", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Spacer()

                Picker("Chart", selection: $selectedTab) {
                    ForEach(availableTabs) { tab in
                        Text(tab.titleUk).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            if chartPoints.isEmpty {
                emptyTelemetryCard
            } else {
                // Interactive Scrubbing Tooltip
                if let p = selectedPoint {
                    interactiveTooltip(for: p)
                }

                // Active Chart
                switch selectedTab {
                case .heartRate:
                    heartRateChart
                case .pace:
                    paceChart
                case .elevation:
                    elevationChart
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 20)
    }

    private var availableTabs: [TelemetryChartTab] {
        if series.isIndoor || chartPoints.allSatisfy({ $0.altitudeM == nil }) {
            return [.heartRate, .pace]
        }
        return TelemetryChartTab.allCases
    }

    // MARK: - 1. Heart Rate Chart

    private var heartRateChart: some View {
        let validHrPoints = chartPoints.filter { $0.heartRate != nil }
        let minHr = max(40.0, (validHrPoints.compactMap { $0.heartRate }.min() ?? 100.0) - 10.0)
        let maxHr = min(220.0, (validHrPoints.compactMap { $0.heartRate }.max() ?? 180.0) + 10.0)

        return Chart {
            // Gradient fill
            ForEach(validHrPoints) { p in
                AreaMark(
                    x: .value("Distance (km)", p.distanceKm),
                    yStart: .value("Baseline HR", minHr),
                    yEnd: .value("Heart Rate", p.heartRate!)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [LifecoreTheme.statusDanger.opacity(0.25), LifecoreTheme.statusDanger.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Distance (km)", p.distanceKm),
                    y: .value("Heart Rate", p.heartRate!)
                )
                .foregroundStyle(LifecoreTheme.statusDanger)
                .lineStyle(StrokeStyle(lineWidth: 2.2))
            }

            if let avg = avgHeartRate {
                RuleMark(y: .value("Avg HR", avg))
                    .foregroundStyle(LifecoreTheme.inkTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Сер: \(Int(avg)) bpm")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
            }

            if let p = selectedPoint, let hr = p.heartRate {
                RuleMark(x: .value("Selected Distance", p.distanceKm))
                    .foregroundStyle(LifecoreTheme.accentTeal)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                PointMark(
                    x: .value("Selected Distance", p.distanceKm),
                    y: .value("Heart Rate", hr)
                )
                .foregroundStyle(LifecoreTheme.accentTeal)
                .symbolSize(45)
            }
        }
        .chartYScale(domain: minHr...maxHr)
        .chartXSelection(value: $selectedDistance)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel {
                    if let hr = value.as(Double.self) {
                        Text("\(Int(hr))")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(String(format: "%.1f", d))
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
            }
        }
        .frame(height: 190)
    }

    // MARK: - 2. Pace Chart

    @ViewBuilder
    private var paceChart: some View {
        let validPacePoints = chartPoints.filter { $0.paceMinKm != nil }

        if validPacePoints.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "speedometer")
                    .font(.title2)
                    .foregroundStyle(LifecoreTheme.inkTertiary)
                Text("Дані темпу недоступні для цього тренування.")
                    .font(.system(size: 12))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
        } else {
            Chart {
                ForEach(validPacePoints) { p in
                    LineMark(
                        x: .value("Distance (km)", p.distanceKm),
                        y: .value("Pace", p.paceMinKm!)
                    )
                    .foregroundStyle(LifecoreTheme.accentTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }

                if let avg = avgPaceMinKm {
                    RuleMark(y: .value("Avg Pace", avg))
                        .foregroundStyle(LifecoreTheme.inkTertiary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Сер: \(formatPace(avg))")
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(LifecoreTheme.inkTertiary)
                        }
                }

                if let p = selectedPoint, let pace = p.paceMinKm {
                    RuleMark(x: .value("Selected Distance", p.distanceKm))
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))

                    PointMark(
                        x: .value("Selected Distance", p.distanceKm),
                        y: .value("Pace", pace)
                    )
                    .foregroundStyle(LifecoreTheme.statusOptimal)
                    .symbolSize(45)
                }
            }
            // Invert Y scale safely so smaller min/km (faster pace) is at top without crashing ClosedRange
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartXSelection(value: $selectedDistance)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(LifecoreTheme.ruleHairline)
                    AxisValueLabel {
                        if let pace = value.as(Double.self) {
                            let totalSec = max(0, Int(round(pace * 60.0)))
                            let m = totalSec / 60
                            let s = totalSec % 60
                            Text(String(format: "%d:%02d", m, s))
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(LifecoreTheme.inkTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(LifecoreTheme.ruleHairline)
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(String(format: "%.1f", d))
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(LifecoreTheme.inkTertiary)
                        }
                    }
                }
            }
            .frame(height: 190)
        }
    }

    // MARK: - 3. Elevation Chart

    private var elevationChart: some View {
        let validAltPoints = chartPoints.filter { $0.altitudeM != nil }
        let minAlt = (validAltPoints.compactMap { $0.altitudeM }.min() ?? 0.0) - 5.0
        let maxAlt = (validAltPoints.compactMap { $0.altitudeM }.max() ?? 100.0) + 10.0

        return Chart {
            ForEach(validAltPoints) { p in
                AreaMark(
                    x: .value("Distance (km)", p.distanceKm),
                    yStart: .value("Base Alt", minAlt),
                    yEnd: .value("Altitude", p.altitudeM!)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [LifecoreTheme.statusOptimal.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Distance (km)", p.distanceKm),
                    y: .value("Altitude", p.altitudeM!)
                )
                .foregroundStyle(LifecoreTheme.statusOptimal)
                .lineStyle(StrokeStyle(lineWidth: 2.0))
            }

            if let p = selectedPoint, let alt = p.altitudeM {
                RuleMark(x: .value("Selected Distance", p.distanceKm))
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                PointMark(
                    x: .value("Selected Distance", p.distanceKm),
                    y: .value("Altitude", alt)
                )
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .symbolSize(45)
            }
        }
        .chartYScale(domain: minAlt...maxAlt)
        .chartXSelection(value: $selectedDistance)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel {
                    if let alt = value.as(Double.self) {
                        Text("\(Int(alt)) м")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(String(format: "%.1f", d))
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
            }
        }
        .frame(height: 190)
    }

    // MARK: - Tooltip & Empty States

    private func interactiveTooltip(for point: ChartDataPoint) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%.2f км", point.distanceKm))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.accentTeal)

            if let hr = point.heartRate {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(LifecoreTheme.statusDanger)
                    Text("\(Int(hr)) bpm")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                }
            }

            if let pace = point.paceMinKm {
                Text(formatPace(pace))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }

            if let alt = point.altitudeM {
                Text(String(format: "%.0f м", alt))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.statusOptimal)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(LifecoreTheme.paperWell)
        )
        .overlay(
            Capsule()
                .stroke(LifecoreTheme.ruleHairline, lineWidth: 1.0)
        )
    }

    private func formatPace(_ pace: Double) -> String {
        let totalSec = max(0, Int(round(pace * 60.0)))
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d/km", m, s)
    }

    private var emptyTelemetryCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text("Телеметрія для цього тренування відсутня.")
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
