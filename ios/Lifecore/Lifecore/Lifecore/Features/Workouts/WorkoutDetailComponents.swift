import SwiftUI

// MARK: - 1. Efficiency Factor & Cardiac Drift Cards

public struct EfficiencyFactorCard: View {
    public let efficiencyFactor: Double?

    public init(efficiencyFactor: Double?) {
        self.efficiencyFactor = efficiencyFactor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Efficiency Factor", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.subheadline)
                    .foregroundStyle(.cyan)
                Spacer()
                Text("EF (Speed / HR)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let ef = efficiencyFactor {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.3f", ef))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("m/min/bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Швидкість пересування на 1 удар серця за хвилину. Зростання EF вказує на зміцнення аеробного двигуна.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Недостатньо телеметрії для розрахунку EF.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

public struct CardiacDriftCard: View {
    public let driftPct: Double?

    public init(driftPct: Double?) {
        self.driftPct = driftPct
    }

    private var statusInfo: (badge: String, color: Color, desc: String) {
        guard let drift = driftPct else {
            return ("Немає даних", .secondary, "Недостатньо точок телеметрії для оцінки роз'єднання.")
        }
        if drift < 5.0 {
            return ("Мінімальний (<5%)", Color.green, "Аеробна база відпрацювала монолітно. Пульс залишався зв'язаним із темпом.")
        } else if drift < 10.0 {
            return ("Помірний (5-10%)", Color.orange, "Помірне кардіоваскулярне роз'єднання у другій половині дистанції.")
        } else {
            return ("Підвищений (>10%)", Color.red, "Значний серцевий дрейф. Ознака накопиченої втоми міокарда, зневоднення або дефіциту глікогену.")
        }
    }

    public var body: some View {
        let info = statusInfo
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Cardiac Drift", systemImage: "arrow.triangle.pull")
                    .font(.subheadline)
                    .foregroundStyle(info.color)
                Spacer()
                Text(info.badge)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(info.color.opacity(0.18))
                    .foregroundStyle(info.color)
                    .clipShape(Capsule())
            }

            if let drift = driftPct {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%+.1f", drift))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(info.color)
                    Text("%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(info.color)
                }

                Text(info.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(info.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 2. Benchmark Comparison Card

public struct BenchmarkComparisonCard: View {
    public let benchmark: BenchmarkDelta?

    public init(benchmark: BenchmarkDelta?) {
        self.benchmark = benchmark
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Динаміка форми", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Spacer()
                if let count = benchmark?.comparedWorkoutsCount, count > 0 {
                    Text("\(count) схожих забігів")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let b = benchmark {
                HStack(spacing: 16) {
                    deltaItem(
                        title: "Різниця темпу",
                        value: String(format: "%+.1f с/км", b.paceDeltaSecPerKm),
                        isPositiveGood: false,
                        actualValue: b.paceDeltaSecPerKm
                    )

                    deltaItem(
                        title: "Різниця пульсу",
                        value: String(format: "%+.1f уд/хв", b.hrDeltaBpm),
                        isPositiveGood: false,
                        actualValue: b.hrDeltaBpm
                    )

                    deltaItem(
                        title: "Ефективність",
                        value: String(format: "%+.3f", b.efDelta),
                        isPositiveGood: true,
                        actualValue: b.efDelta
                    )
                }

                Divider().background(Color.white.opacity(0.1))

                Text(b.narrativeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Попередніх сесій із близькою дистанцією (±25%) для статистичного порівняння не знайдено.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func deltaItem(title: String, value: String, isPositiveGood: Bool, actualValue: Double) -> some View {
        let isFavorable = isPositiveGood ? (actualValue > 0) : (actualValue < 0)
        let isNeutral = abs(actualValue) < 0.01
        let color: Color = isNeutral ? .secondary : (isFavorable ? .green : .orange)

        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 3. 1km Splits Table View

public struct SplitsTableView: View {
    public let splits: [SplitMetric]

    public init(splits: [SplitMetric]) {
        self.splits = splits
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("1km Auto-Splits", systemImage: "flag.checkered")
                .font(.headline)
                .foregroundStyle(.green)

            if splits.isEmpty {
                Text("Відрізки ще не зафіксовано або сесія коротша за 1 км.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Table Header
                HStack {
                    Text("Км").frame(width: 34, alignment: .leading)
                    Text("Темп").frame(width: 70, alignment: .leading)
                    Text("Сер. ЧСС").frame(width: 65, alignment: .center)
                    Text("Пік ЧСС").frame(width: 65, alignment: .center)
                    Text("Δh").frame(width: 45, alignment: .trailing)
                    Spacer()
                    Text("Каденс").frame(width: 55, alignment: .trailing)
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

                Divider().background(Color.white.opacity(0.1))

                // Rows
                ForEach(splits) { split in
                    HStack {
                        Text("\(split.km)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 34, alignment: .leading)

                        Text(split.formattedPace)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.cyan)
                            .frame(width: 70, alignment: .leading)

                        Text(split.avgHeartRate != nil ? "\(Int(round(split.avgHeartRate!)))" : "—")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(width: 65, alignment: .center)

                        Text(split.maxHeartRate != nil ? "\(Int(round(split.maxHeartRate!)))" : "—")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(width: 65, alignment: .center)

                        Text(String(format: "%+.0f", split.elevationDiffMeters))
                            .font(.caption)
                            .foregroundStyle(split.elevationDiffMeters > 0 ? .orange : (split.elevationDiffMeters < 0 ? .green : .secondary))
                            .frame(width: 45, alignment: .trailing)

                        Spacer()

                        Text(split.avgCadence != nil ? "\(Int(round(split.avgCadence!)))" : "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 55, alignment: .trailing)
                    }
                    .padding(.vertical, 4)

                    if split.km != splits.last?.km {
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - 4. Structured Interval Laps Table View

public struct IntervalLapsTableView: View {
    public let laps: [LapIntervalMetric]

    public init(laps: [LapIntervalMetric]) {
        self.laps = laps
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Structured Interval Laps", systemImage: "timer")
                .font(.headline)
                .foregroundStyle(.orange)

            // Table Header
            HStack {
                Text("#").frame(width: 25, alignment: .leading)
                Text("Тип").frame(width: 75, alignment: .leading)
                Text("Час").frame(width: 55, alignment: .leading)
                Text("Дист").frame(width: 60, alignment: .trailing)
                Text("ЧСС").frame(width: 55, alignment: .center)
                Spacer()
                Text("HR drop").frame(width: 60, alignment: .trailing)
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)

            Divider().background(Color.white.opacity(0.1))

            ForEach(laps) { lap in
                let isWork = lap.lapType.lowercased() == "work"
                HStack {
                    Text("\(lap.lapIndex)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 25, alignment: .leading)

                    Text(lap.lapType.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((isWork ? Color.orange : Color.indigo).opacity(0.2))
                        .foregroundStyle(isWork ? Color.orange : Color.indigo)
                        .clipShape(Capsule())
                        .frame(width: 75, alignment: .leading)

                    let mins = Int(lap.durationSeconds) / 60
                    let secs = Int(lap.durationSeconds) % 60
                    Text(String(format: "%d:%02d", mins, secs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 55, alignment: .leading)

                    Text(lap.distanceMeters != nil ? String(format: "%.0fm", lap.distanceMeters!) : "—")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .frame(width: 60, alignment: .trailing)

                    Text(lap.avgHeartRate != nil ? "\(Int(round(lap.avgHeartRate!)))" : "—")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(width: 55, alignment: .center)

                    Spacer()

                    if let drop = lap.hrRecoveryDropBpm {
                        Text(String(format: "-%.0f", drop))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                            .frame(width: 60, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)

                if lap.lapIndex != laps.last?.lapIndex {
                    Divider().background(Color.white.opacity(0.05))
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
