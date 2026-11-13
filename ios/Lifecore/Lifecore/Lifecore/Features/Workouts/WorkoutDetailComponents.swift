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
                Label("Ефективність (EF)", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LifecoreTheme.accentTeal)
                Spacer()
                Text("EF (Швидкість / ЧСС)")
                    .font(.system(size: 10))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }

            if let ef = efficiencyFactor {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.3f", ef))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                    Text("м/хв/уд")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }

                Text("Швидкість пересування на 1 удар серця за хвилину. Зростання EF вказує на зміцнення аеробного двигуна.")
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .lineSpacing(2)
            } else {
                Text("Недостатньо телеметрії для розрахунку EF.")
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .lifecoreGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(efficiencyFactor.map {
            "Ефективність бігу EF: \(String(format: "%.3f", $0)) метрів на хвилину на удар серця."
        } ?? "Ефективність бігу EF: дані відсутні.")
    }
}

public struct CardiacDriftCard: View {
    public let driftPct: Double?

    public init(driftPct: Double?) {
        self.driftPct = driftPct
    }

    private var statusInfo: (badge: String, color: Color, desc: String) {
        guard let drift = driftPct else {
            return ("Немає даних", LifecoreTheme.inkTertiary, "Недостатньо точок телеметрії для оцінки роз'єднання.")
        }
        if drift < 5.0 {
            return ("Мінімальний (<5%)", LifecoreTheme.statusOptimal, "Аеробна база відпрацювала монолітно. Пульс залишався зв'язаним із темпом.")
        } else if drift < 10.0 {
            return ("Помірний (5-10%)", LifecoreTheme.statusWarning, "Помірне кардіоваскулярне роз'єднання у другій половині дистанції.")
        } else {
            return ("Підвищений (>10%)", LifecoreTheme.statusDanger, "Значний серцевий дрейф. Ознака накопиченої втоми міокарда, зневоднення або дефіциту глікогену.")
        }
    }

    public var body: some View {
        let info = statusInfo
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Серцевий дрейф", systemImage: "arrow.triangle.pull")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(info.color)
                Spacer()
                Text(info.badge)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(info.color.opacity(0.12))
                    .foregroundStyle(info.color)
                    .clipShape(Capsule())
            }

            if let drift = driftPct {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%+.1f", drift))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(info.color)
                    Text("%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(info.color)
                }

                Text(info.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .lineSpacing(2)
            } else {
                Text(info.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .lifecoreGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(driftPct.map {
            "Серцевий дрейф: \(String(format: "%+.1f", $0)) відсотків. Статус: \(info.badge)."
        } ?? "Серцевий дрейф: дані відсутні.")
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.accentIndigo)
                Spacer()
                if let b = benchmark {
                    let regimeColor: Color = {
                        switch b.regime {
                        case .trueAerobicGain: return LifecoreTheme.statusOptimal
                        case .higherIntensityEffort: return LifecoreTheme.accentTeal
                        case .easyRecoveryEffort: return LifecoreTheme.accentIndigo
                        case .cardiacStrainDecoupling: return LifecoreTheme.statusWarning
                        case .steadyBaseline: return LifecoreTheme.inkTertiary
                        }
                    }()
                    Text(b.regime.badgeTitleUk)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(regimeColor.opacity(0.12))
                        .foregroundStyle(regimeColor)
                        .clipShape(Capsule())
                } else if let count = benchmark?.comparedWorkoutsCount, count > 0 {
                    Text("\(count) схожих забігів")
                        .font(.system(size: 11))
                        .foregroundStyle(LifecoreTheme.inkTertiary)
                }
            }

            if let b = benchmark {
                HStack(spacing: 12) {
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
                        value: String(format: "%+.3f EF", b.efDelta),
                        isPositiveGood: true,
                        actualValue: b.efDelta
                    )
                }

                LifecoreHairlineDivider()

                Text(b.narrativeSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .lineSpacing(2)
            } else {
                Text("Попередніх сесій із близькою дистанцією (±25%) для статистичного порівняння не знайдено.")
                    .font(.system(size: 12))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .lifecoreGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(benchmark.map {
            "Порівняння форми: \($0.regime.badgeTitleUk). Різниця темпу: \(String(format: "%+.1f", $0.paceDeltaSecPerKm)) секунд на кілометр, різниця пульсу: \(String(format: "%+.1f", $0.hrDeltaBpm)) ударів на хвилину."
        } ?? "Динаміка форми: немає попередніх сесій для порівняння.")
    }

    private func deltaItem(title: String, value: String, isPositiveGood: Bool, actualValue: Double) -> some View {
        let isFavorable = isPositiveGood ? (actualValue > 0) : (actualValue < 0)
        let isNeutral = abs(actualValue) < 0.01
        let color: Color = isNeutral ? LifecoreTheme.inkTertiary : (isFavorable ? LifecoreTheme.statusOptimal : LifecoreTheme.statusWarning)

        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
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
            HStack {
                Label("1 км спліти", systemImage: "flag.checkered")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.statusOptimal)
                Spacer()
                Text("Одиниці: хв/км · уд/хв · м")
                    .font(.system(size: 10))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }

            if splits.isEmpty {
                Text("Відрізки темпу не зафіксовано або сесія коротша за 1 км.")
                    .font(.system(size: 12))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            } else {
                // Table Header
                HStack {
                    Text("Км").frame(width: 32, alignment: .leading)
                    Text("Темп").frame(width: 72, alignment: .leading)
                    Text("Сер. ЧСС").frame(width: 65, alignment: .center)
                    Text("Пік ЧСС").frame(width: 65, alignment: .center)
                    Text("Δh (м)").frame(width: 48, alignment: .trailing)
                    Spacer()
                    Text("Каденс").frame(width: 55, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LifecoreTheme.inkTertiary)

                LifecoreHairlineDivider()

                // Rows
                ForEach(splits) { split in
                    HStack {
                        Text("\(split.km)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                            .frame(width: 32, alignment: .leading)

                        Text(split.formattedPace)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.accentTeal)
                            .frame(width: 72, alignment: .leading)

                        Text(split.avgHeartRate != nil ? "\(Int(round(split.avgHeartRate!)))" : "—")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                            .frame(width: 65, alignment: .center)

                        Text(split.maxHeartRate != nil ? "\(Int(round(split.maxHeartRate!)))" : "—")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.statusDanger)
                            .frame(width: 65, alignment: .center)

                        Text(String(format: "%+.0f", split.elevationDiffMeters))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(
                                split.elevationDiffMeters > 0 ? LifecoreTheme.statusWarning :
                                (split.elevationDiffMeters < 0 ? LifecoreTheme.statusOptimal : LifecoreTheme.inkTertiary)
                            )
                            .frame(width: 48, alignment: .trailing)

                        Spacer()

                        Text(split.avgCadence != nil ? "\(Int(round(split.avgCadence!)))" : "—")
                            .font(.system(size: 12, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                            .frame(width: 55, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Кілометр \(split.km): темп \(split.formattedPace), середній пульс \(split.avgHeartRate.map { "\(Int(round($0))) уд/хв" } ?? "невідомо"), перепад висоти \(Int(round(split.elevationDiffMeters))) метрів.")

                    if split.km != splits.last?.km {
                        LifecoreHairlineDivider()
                    }
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 18)
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
            HStack {
                Label("Інтервальні відрізки", systemImage: "timer")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.statusWarning)
                Spacer()
                Text("Одиниці: м · уд/хв")
                    .font(.system(size: 10))
                    .foregroundStyle(LifecoreTheme.inkTertiary)
            }

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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(LifecoreTheme.inkTertiary)

            LifecoreHairlineDivider()

            ForEach(laps) { lap in
                let isWork = lap.lapType.lowercased() == "work"
                let lapBadgeColor = isWork ? LifecoreTheme.statusWarning : LifecoreTheme.accentIndigo
                HStack {
                    Text("\(lap.lapIndex)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                        .frame(width: 25, alignment: .leading)

                    Text(lap.lapType.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(lapBadgeColor.opacity(0.12))
                        .foregroundStyle(lapBadgeColor)
                        .clipShape(Capsule())
                        .frame(width: 75, alignment: .leading)

                    let mins = Int(lap.durationSeconds) / 60
                    let secs = Int(lap.durationSeconds) % 60
                    Text(String(format: "%d:%02d", mins, secs))
                        .font(.system(size: 12, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                        .frame(width: 55, alignment: .leading)

                    Text(lap.distanceMeters != nil ? String(format: "%.0f м", lap.distanceMeters!) : "—")
                        .font(.system(size: 12, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                        .frame(width: 60, alignment: .trailing)

                    Text(lap.avgHeartRate != nil ? "\(Int(round(lap.avgHeartRate!)))" : "—")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.statusDanger)
                        .frame(width: 55, alignment: .center)

                    Spacer()

                    if let drop = lap.hrRecoveryDropBpm {
                        Text(String(format: "-%.0f", drop))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.statusOptimal)
                            .frame(width: 60, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.system(size: 12))
                            .foregroundStyle(LifecoreTheme.inkTertiary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Відрізок \(lap.lapIndex): тип \(lap.lapType), тривалість \(Int(lap.durationSeconds)) секунд, середній пульс \(lap.avgHeartRate.map { "\(Int(round($0))) уд/хв" } ?? "невідомо").")

                if lap.lapIndex != laps.last?.lapIndex {
                    LifecoreHairlineDivider()
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 18)
    }
}

// MARK: - 5. Cycling Presentation Card

public struct CyclingMetricsCard: View {
    public let metrics: CyclingPresentationMetrics

    public init(metrics: CyclingPresentationMetrics) {
        self.metrics = metrics
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Показники велотренування", systemImage: "figure.outdoor.cycle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.accentTeal)
                Spacer()
            }

            HStack(spacing: 12) {
                metricColumn(
                    title: "Швидкість",
                    value: metrics.formattedSpeed,
                    color: LifecoreTheme.statusOptimal
                )

                metricColumn(
                    title: "Дистанція",
                    value: metrics.formattedDistance,
                    color: LifecoreTheme.accentTeal
                )

                metricColumn(
                    title: "Час",
                    value: metrics.formattedDuration,
                    color: LifecoreTheme.inkPrimary
                )

                if let elev = metrics.elevationGainMeters, elev > 0 {
                    metricColumn(
                        title: "Набір висоти",
                        value: "\(Int(elev)) м",
                        color: LifecoreTheme.statusWarning
                    )
                }
            }

            if let avg = metrics.avgHeartRate {
                LifecoreHairlineDivider()

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LifecoreTheme.statusDanger)
                        Text("Сер. ЧСС: \(Int(avg)) уд/хв")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                    }

                    if let maxHr = metrics.maxHeartRate {
                        Text("Пік ЧСС: \(Int(maxHr)) уд/хв")
                            .font(.system(size: 12, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                    Spacer()
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Велотренування: швидкість \(metrics.formattedSpeed), дистанція \(metrics.formattedDistance), тривалість \(metrics.formattedDuration).")
    }

    private func metricColumn(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 6. Strength & Other Presentation Card

public struct StrengthMetricsCard: View {
    public let metrics: StrengthPresentationMetrics
    public let titleUk: String

    public init(metrics: StrengthPresentationMetrics, titleUk: String = "Силове тренування") {
        self.metrics = metrics
        self.titleUk = titleUk
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(titleUk, systemImage: "figure.strengthtraining.traditional")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifecoreTheme.statusWarning)
                Spacer()

                if let trimp = metrics.banisterTrimp {
                    LifecoreGlowPill(
                        text: "\(metrics.effortLevelUk) (\(Int(trimp)) TRIMP)",
                        systemIcon: "flame.fill",
                        color: LifecoreTheme.statusWarning
                    )
                }
            }

            HStack(spacing: 12) {
                metricColumn(
                    title: "Тривалість",
                    value: metrics.formattedDuration,
                    color: LifecoreTheme.inkPrimary
                )

                if let hr = metrics.avgHeartRate {
                    metricColumn(
                        title: "Сер. ЧСС",
                        value: "\(Int(hr)) уд/хв",
                        color: LifecoreTheme.statusDanger
                    )
                }

                if let maxHr = metrics.maxHeartRate {
                    metricColumn(
                        title: "Пік ЧСС",
                        value: "\(Int(maxHr)) уд/хв",
                        color: LifecoreTheme.statusWarning
                    )
                }

                if let kcal = metrics.caloriesKcal {
                    metricColumn(
                        title: "Спалено",
                        value: "\(Int(kcal)) ккал",
                        color: LifecoreTheme.accentTeal
                    )
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titleUk): тривалість \(metrics.formattedDuration).")
    }

    private func metricColumn(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 7. Stream Signal Note Card

public struct StreamSignalNoteCard: View {
    public let noteUk: String

    public init(noteUk: String) {
        self.noteUk = noteUk
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LifecoreTheme.inkTertiary)
                .padding(.top, 1)

            Text(noteUk)
                .font(.system(size: 12))
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .lineSpacing(2)

            Spacer()
        }
        .lifecoreWell(cornerRadius: 14, padding: 10)
    }
}
