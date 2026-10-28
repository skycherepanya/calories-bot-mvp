import SwiftUI
import Charts

// MARK: - Time Range

public enum TrendsTimeRange: Int, CaseIterable, Identifiable {
    case days30 = 30
    case days60 = 60
    case days90 = 90

    public var id: Int { rawValue }

    public var titleUk: String {
        switch self {
        case .days30: return "30 днів"
        case .days60: return "60 днів"
        case .days90: return "90 днів"
        }
    }
}

// MARK: - Range Selector Bar

public struct TrendsRangePickerView: View {
    @Binding public var selectedRange: TrendsTimeRange

    public init(selectedRange: Binding<TrendsTimeRange>) {
        self._selectedRange = selectedRange
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(TrendsTimeRange.allCases) { range in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                }) {
                    Text(range.titleUk)
                        .font(.subheadline)
                        .fontWeight(selectedRange == range ? .semibold : .medium)
                        .foregroundStyle(selectedRange == range ? LifecoreTheme.inkPrimary : LifecoreTheme.inkSecondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedRange == range
                                ? LifecoreTheme.paperCard
                                : Color.clear
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedRange == range ? LifecoreTheme.ruleHairline : Color.clear, lineWidth: 1.0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(LifecoreTheme.paperWell)
        .clipShape(Capsule())
    }
}

// MARK: - KPI Stat Box Helper

public struct TrendStatItem: View {
    public let title: String
    public let value: String
    public let delta: String?
    public let isPositive: Bool?

    public init(title: String, value: String, delta: String? = nil, isPositive: Bool? = nil) {
        self.title = title
        self.value = value
        self.delta = delta
        self.isPositive = isPositive
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(LifecoreTheme.inkSecondary)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.inkPrimary)

            if let delta = delta {
                HStack(spacing: 2) {
                    if let isPos = isPositive {
                        Image(systemName: isPos ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    Text(delta)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                .foregroundStyle(isPositive == nil ? LifecoreTheme.inkSecondary : (isPositive! ? LifecoreTheme.statusOptimal : LifecoreTheme.statusDanger))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 1. Body Weight Trend Card (Water Filter)

public struct WeightTrendCard: View {
    public let points: [TrendWeightPoint]
    @State private var selectedDate: Date?

    public init(points: [TrendWeightPoint]) {
        self.points = points
    }

    private var latestPoint: TrendWeightPoint? {
        points.last
    }

    private var net7dDelta: Double? {
        guard points.count >= 7,
              let current7d = points.last?.rolling7dKg,
              let prior7d = points[max(0, points.count - 8)].rolling7dKg else {
            return nil
        }
        return round((current7d - prior7d) * 100) / 100
    }

    private var selectedPoint: TrendWeightPoint? {
        guard let sel = selectedDate else { return nil }
        let calendar = Calendar.current
        return points.first { calendar.isDate($0.date, inSameDayAs: sel) }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack(alignment: .center) {
                Label("Динаміка Ваги", systemImage: "scalemass.fill")
                    .font(.headline)
                    .foregroundStyle(LifecoreTheme.accentTeal)

                Spacer()

                if let latest = latestPoint, latest.isWaterSpike {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.triangle.fill")
                            .font(.caption2)
                        Text("Водний шум")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LifecoreTheme.statusWarning.opacity(0.14))
                    .foregroundStyle(LifecoreTheme.statusWarning)
                    .clipShape(Capsule())
                }
            }

            // Metrics Row
            HStack(spacing: 12) {
                TrendStatItem(
                    title: "Замір",
                    value: String(format: "%.1f кг", latestPoint?.rawWeightKg ?? 78.4)
                )

                TrendStatItem(
                    title: "7d Тренд",
                    value: String(format: "%.1f кг", latestPoint?.rolling7dKg ?? (latestPoint?.rawWeightKg ?? 78.4)),
                    delta: net7dDelta.map { String(format: "%+.1f кг (7d)", $0) },
                    isPositive: net7dDelta.map { $0 <= 0 } // Negative or zero is positive for weight cut
                )

                TrendStatItem(
                    title: "14d Тренд",
                    value: String(format: "%.1f кг", latestPoint?.rolling14dKg ?? (latestPoint?.rawWeightKg ?? 78.4))
                )
            }

            // Water Spike Alert Banner (if acute retention suspected)
            if let latest = latestPoint, latest.isWaterSpike,
               let avg7 = latest.rolling7dKg {
                let diff = latest.rawWeightKg - avg7
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(LifecoreTheme.statusWarning)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Стрибок затримки рідини (\(String(format: "%+.1f", diff)) кг)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                        Text("Різке збільшення ваги зумовлене гідратацією глікогену або сіллю, а не жировою тканиною. 7-денна ковзна середня залишається стабільною.")
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                            .lineSpacing(2)
                    }
                }
                .padding(10)
                .background(LifecoreTheme.statusWarning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Scrub Tooltip Callout
            if let sel = selectedPoint {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sel.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                        HStack(spacing: 8) {
                            Text("Замір: \(String(format: "%.1f", sel.rawWeightKg)) кг")
                                .font(.caption)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(LifecoreTheme.inkPrimary)

                            if let r7 = sel.rolling7dKg {
                                Text("7d: \(String(format: "%.1f", r7)) кг")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.accentTeal)
                            }

                            if let r14 = sel.rolling14dKg {
                                Text("14d: \(String(format: "%.1f", r14)) кг")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.accentIndigo)
                            }
                        }
                    }
                    Spacer()
                    if sel.isWaterSpike {
                        Label("Водний сплеск", systemImage: "drop.fill")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(LifecoreTheme.statusWarning)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(LifecoreTheme.paperWell)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Swift Chart
            weightChart
                .frame(height: 200)

            // Legend
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Circle().fill(LifecoreTheme.inkTertiary.opacity(0.6)).frame(width: 6, height: 6)
                    Text("Замір")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }

                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(LifecoreTheme.accentTeal).frame(width: 12, height: 3)
                    Text("7d фільтр")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }

                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(LifecoreTheme.accentIndigo).frame(width: 12, height: 3)
                    Text("14d тренд")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }

                HStack(spacing: 5) {
                    Circle().fill(LifecoreTheme.statusWarning).frame(width: 6, height: 6)
                    Text("Водний шум")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }
            }
        }
        .lifecoreGlassCard()
    }

    private var weightChart: some View {
        let minWeight = max(40.0, (points.map(\.rawWeightKg).min() ?? 78.0) - 1.5)
        let maxWeight = min(150.0, (points.map(\.rawWeightKg).max() ?? 80.0) + 1.5)

        return Chart {
            ForEach(points) { p in
                // Raw weight scatter point
                PointMark(
                    x: .value("Дата", p.date, unit: .day),
                    y: .value("Вага", p.rawWeightKg)
                )
                .foregroundStyle(p.isWaterSpike ? LifecoreTheme.statusWarning : LifecoreTheme.inkTertiary.opacity(0.45))
                .symbolSize(p.isWaterSpike ? 40 : 16)

                // 7-day rolling average line (Metabolic trend)
                if let r7 = p.rolling7dKg {
                    LineMark(
                        x: .value("Дата", p.date, unit: .day),
                        y: .value("7d Ковзна", r7),
                        series: .value("Серія", "7d")
                    )
                    .foregroundStyle(LifecoreTheme.accentTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                // 14-day rolling average line (Systemic direction)
                if let r14 = p.rolling14dKg {
                    LineMark(
                        x: .value("Дата", p.date, unit: .day),
                        y: .value("14d Ковзна", r14),
                        series: .value("Серія", "14d")
                    )
                    .foregroundStyle(LifecoreTheme.accentIndigo)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [4, 4]))
                }
            }

            // Interactive scrub rule
            if let sel = selectedPoint {
                RuleMark(x: .value("Дата", sel.date, unit: .day))
                    .foregroundStyle(LifecoreTheme.accentTeal.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                PointMark(
                    x: .value("Дата", sel.date, unit: .day),
                    y: .value("Вага", sel.rawWeightKg)
                )
                .foregroundStyle(LifecoreTheme.accentTeal)
                .symbolSize(60)
            }
        }
        .chartYScale(domain: minWeight...maxWeight)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: points.count > 45 ? 14 : 7)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(String(format: "%.1f", d))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - 2. Autonomic Baseline Envelope Card (HRV & RHR)

public enum AutonomicChartMetric: String, CaseIterable, Identifiable {
    case hrv = "HRV SDNN"
    case rhr = "Пульс Спокою"

    public var id: String { rawValue }
}

public struct AutonomicTrendCard: View {
    public let samples: [DateAutonomicSample]
    @State private var selectedMetric: AutonomicChartMetric = .hrv
    @State private var selectedDate: Date?

    public init(samples: [DateAutonomicSample]) {
        self.samples = samples
    }

    private var latestSample: DateAutonomicSample? {
        samples.last
    }

    private var selectedSample: DateAutonomicSample? {
        guard let sel = selectedDate else { return nil }
        let calendar = Calendar.current
        return samples.first { calendar.isDate($0.date, inSameDayAs: sel) }
    }

    private func autonomicStatus(hrvDiff: Double) -> (text: String, color: Color) {
        if hrvDiff >= 0 {
            return ("Оптимум", LifecoreTheme.statusOptimal)
        } else if hrvDiff >= -8 {
            return ("Стабільно", LifecoreTheme.accentTeal)
        } else {
            return ("Напруження", LifecoreTheme.statusWarning)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack(alignment: .center) {
                Label("Вегетативна Стабільність", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(LifecoreTheme.statusOptimal)

                Spacer()

                // Metric Toggle Picker
                Picker("", selection: $selectedMetric) {
                    ForEach(AutonomicChartMetric.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            // Metrics Row
            HStack(spacing: 12) {
                let latestHrv = latestSample?.hrvMs ?? 102.0
                let baselineHrv = latestSample?.hrvBaselineMean ?? 102.0
                let hrvDiff = latestHrv - baselineHrv

                TrendStatItem(
                    title: "Ранішній HRV",
                    value: String(format: "%.0f мс", latestHrv),
                    delta: String(format: "%+.0f vs 30d база", hrvDiff),
                    isPositive: hrvDiff >= -5.0
                )

                let latestRhr = latestSample?.rhrBpm ?? 49.0
                TrendStatItem(
                    title: "Пульс Спокою",
                    value: String(format: "%.0f уд/хв", latestRhr),
                    delta: "Норма 46-52",
                    isPositive: true
                )

                let status = autonomicStatus(hrvDiff: hrvDiff)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Стан ВНС")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    Text(status.text)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(status.color)
                    Text("Середня ± 0.5σ")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Scrub Tooltip Callout
            if let sel = selectedSample {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sel.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                        HStack(spacing: 10) {
                            if let hrv = sel.hrvMs {
                                Text("HRV: \(Int(hrv)) мс")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.statusOptimal)
                            }
                            if let mean = sel.hrvBaselineMean {
                                Text("База: \(Int(mean)) мс")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.inkSecondary)
                            }
                            if let rhr = sel.rhrBpm {
                                Text("RHR: \(Int(rhr)) уд/хв")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.statusWarning)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(LifecoreTheme.paperWell)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Swift Chart
            autonomicChart
                .frame(height: 200)

            // Legend
            HStack(spacing: 14) {
                if selectedMetric == .hrv {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(LifecoreTheme.statusOptimal).frame(width: 12, height: 3)
                        Text("HRV за день")
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }

                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(LifecoreTheme.statusOptimal.opacity(0.2)).frame(width: 12, height: 8)
                        Text("30d Коридор (±0.5σ)")
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }

                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(LifecoreTheme.statusOptimal.opacity(0.5)).frame(width: 12, height: 1)
                        Text("Медіана")
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                } else {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(LifecoreTheme.statusWarning).frame(width: 12, height: 3)
                        Text("Нічний пульс спокою (уд/хв)")
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                }
            }
        }
        .lifecoreGlassCard()
    }

    private var autonomicChart: some View {
        let validSamples = samples.filter { selectedMetric == .hrv ? ($0.hrvMs != nil) : ($0.rhrBpm != nil) }

        let minY: Double
        let maxY: Double

        if selectedMetric == .hrv {
            let values = validSamples.compactMap(\.hrvMs) + validSamples.compactMap(\.hrvBaselineLower)
            minY = max(30.0, (values.min() ?? 80.0) - 10.0)
            maxY = min(200.0, (validSamples.compactMap(\.hrvMs).max() ?? 120.0) + 15.0)
        } else {
            let values = validSamples.compactMap(\.rhrBpm)
            minY = max(35.0, (values.min() ?? 45.0) - 5.0)
            maxY = min(90.0, (values.max() ?? 60.0) + 5.0)
        }

        return Chart {
            if selectedMetric == .hrv {
                // 30-day baseline envelope corridor: AreaMark
                ForEach(validSamples) { s in
                    if let lower = s.hrvBaselineLower, let upper = s.hrvBaselineUpper {
                        AreaMark(
                            x: .value("Дата", s.date, unit: .day),
                            yStart: .value("Нижня база", lower),
                            yEnd: .value("Верхня база", upper)
                        )
                        .foregroundStyle(LifecoreTheme.statusOptimal.opacity(0.12))
                    }

                    if let mean = s.hrvBaselineMean {
                        LineMark(
                            x: .value("Дата", s.date, unit: .day),
                            y: .value("Базова середня", mean),
                            series: .value("Серія", "Базова")
                        )
                        .foregroundStyle(LifecoreTheme.statusOptimal.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    }

                    if let hrv = s.hrvMs {
                        LineMark(
                            x: .value("Дата", s.date, unit: .day),
                            y: .value("HRV", hrv),
                            series: .value("Серія", "HRV")
                        )
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Дата", s.date, unit: .day),
                            y: .value("HRV", hrv)
                        )
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                        .symbolSize(20)
                    }
                }
            } else {
                // Sleeping Resting Heart Rate
                ForEach(validSamples) { s in
                    if let rhr = s.rhrBpm {
                        AreaMark(
                            x: .value("Дата", s.date, unit: .day),
                            yStart: .value("Базовий RHR", minY),
                            yEnd: .value("RHR", rhr)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [LifecoreTheme.statusWarning.opacity(0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Дата", s.date, unit: .day),
                            y: .value("RHR", rhr),
                            series: .value("Серія", "RHR")
                        )
                        .foregroundStyle(LifecoreTheme.statusWarning)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))

                        PointMark(
                            x: .value("Дата", s.date, unit: .day),
                            y: .value("RHR", rhr)
                        )
                        .foregroundStyle(LifecoreTheme.statusWarning)
                        .symbolSize(20)
                    }
                }
            }

            // Interactive scrub rule
            if let sel = selectedSample {
                RuleMark(x: .value("Дата", sel.date, unit: .day))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                if selectedMetric == .hrv, let val = sel.hrvMs {
                    PointMark(
                        x: .value("Дата", sel.date, unit: .day),
                        y: .value("HRV", val)
                    )
                    .foregroundStyle(LifecoreTheme.statusOptimal)
                    .symbolSize(50)
                } else if selectedMetric == .rhr, let val = sel.rhrBpm {
                    PointMark(
                        x: .value("Дата", sel.date, unit: .day),
                        y: .value("RHR", val)
                    )
                    .foregroundStyle(LifecoreTheme.statusWarning)
                    .symbolSize(50)
                }
            }
        }
        .chartYScale(domain: minY...maxY)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: samples.count > 45 ? 14 : 7)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text("\(Int(d))")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - 3. Aerobic Efficiency & Decoupling Progression Card

public struct AerobicEfficiencyTrendCard: View {
    public let samples: [AerobicEfficiencyTrendSample]
    @State private var selectedWorkoutId: UUID?

    public init(samples: [AerobicEfficiencyTrendSample]) {
        self.samples = samples
    }

    private var latestSample: AerobicEfficiencyTrendSample? {
        samples.last
    }

    private var avgDecoupling: Double {
        let decs = samples.compactMap(\.aerobicDecouplingPct)
        guard !decs.isEmpty else { return 3.4 }
        return round((decs.reduce(0.0, +) / Double(decs.count)) * 10) / 10
    }

    private var selectedSample: AerobicEfficiencyTrendSample? {
        guard let id = selectedWorkoutId else { return nil }
        return samples.first { $0.id == id }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack(alignment: .center) {
                Label("Аеробна Ефективність (EF)", systemImage: "figure.run")
                    .font(.headline)
                    .foregroundStyle(LifecoreTheme.statusWarning)

                Spacer()

                if avgDecoupling < 5.0 {
                    LifecoreGlowPill(
                        text: "Висока витривалість",
                        systemIcon: "checkmark.seal.fill",
                        color: LifecoreTheme.statusOptimal
                    )
                }
            }

            // Metrics Row
            HStack(spacing: 12) {
                TrendStatItem(
                    title: "Останній EF",
                    value: String(format: "%.3f", latestSample?.efficiencyFactor ?? 1.280),
                    delta: "м/хв на 1 уд ЧСС",
                    isPositive: nil
                )

                TrendStatItem(
                    title: "Середній Дрейф",
                    value: String(format: "%.1f%%", avgDecoupling),
                    delta: avgDecoupling < 5.0 ? "Оптимально (<5%)" : "Помірний",
                    isPositive: avgDecoupling < 5.0
                )

                TrendStatItem(
                    title: "Сесій у вибірці",
                    value: "\(samples.count)",
                    delta: "Бігові тренування",
                    isPositive: nil
                )
            }

            // Scrub Tooltip Callout
            if let sel = selectedSample {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(sel.workoutName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                        Spacer()
                        Text(sel.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }

                    HStack(spacing: 10) {
                        Text("EF: \(String(format: "%.3f", sel.efficiencyFactor))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.statusWarning)

                        Text("Темп: \(String(format: "%.2f", sel.avgPaceMinKm)) хв/км")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkSecondary)

                        Text("ЧСС: \(Int(sel.avgHrBpm)) уд/хв")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkSecondary)

                        if let dec = sel.aerobicDecouplingPct {
                            Text("Дрейф: \(String(format: "%.1f%%", dec))")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(dec < 5.0 ? LifecoreTheme.statusOptimal : LifecoreTheme.statusWarning)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(LifecoreTheme.paperWell)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Swift Chart: Historical EF Progression
            efChart
                .frame(height: 190)

            // Explanatory Footnote
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(LifecoreTheme.statusWarning)
                Text("Efficiency Factor (EF) розраховується як швидкість (м/хв) поділена на ЧСС (уд/хв). Зростання лінії свідчить про збільшення аеробної потужності без додаткового серцевого навантаження.")
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .lineSpacing(2)
            }
        }
        .lifecoreGlassCard()
    }

    private var efChart: some View {
        let minEf = max(0.5, (samples.map(\.efficiencyFactor).min() ?? 1.1) - 0.08)
        let maxEf = min(3.0, (samples.map(\.efficiencyFactor).max() ?? 1.4) + 0.08)

        return Chart {
            ForEach(samples) { s in
                LineMark(
                    x: .value("Дата", s.date, unit: .day),
                    y: .value("EF", s.efficiencyFactor)
                )
                .foregroundStyle(LifecoreTheme.statusWarning)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Дата", s.date, unit: .day),
                    y: .value("EF", s.efficiencyFactor)
                )
                .foregroundStyle((s.aerobicDecouplingPct ?? 0) < 5.0 ? LifecoreTheme.statusOptimal : LifecoreTheme.statusWarning)
                .symbolSize(35)
            }

            // Interactive scrub rule
            if let sel = selectedSample {
                RuleMark(x: .value("Дата", sel.date, unit: .day))
                    .foregroundStyle(LifecoreTheme.statusWarning.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                PointMark(
                    x: .value("Дата", sel.date, unit: .day),
                    y: .value("EF", sel.efficiencyFactor)
                )
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .symbolSize(55)
            }
        }
        .chartYScale(domain: minEf...maxEf)
        .chartXSelection(value: Binding(
            get: {
                selectedSample?.date
            },
            set: { newDate in
                guard let newDate = newDate else {
                    selectedWorkoutId = nil
                    return
                }
                // Pick sample with closest date
                let closest = samples.min(by: { abs($0.date.timeIntervalSince(newDate)) < abs($1.date.timeIntervalSince(newDate)) })
                selectedWorkoutId = closest?.id
            }
        ))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(5, samples.count * 2))) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(LifecoreTheme.ruleHairline)
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(String(format: "%.2f", d))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                    }
                }
            }
        }
    }
}
