import SwiftUI

// MARK: - 1. Daily Macro & Calorie Summary Card

public struct MacroSummaryCard: View {
    public let consumedKcal: Double
    public let targetKcal: Double
    public let proteinG: Double
    public let targetProteinG: Double
    public let fatG: Double
    public let targetFatG: Double
    public let carbsG: Double
    public let targetCarbsG: Double

    public init(
        consumedKcal: Double,
        targetKcal: Double = 2400.0,
        proteinG: Double,
        targetProteinG: Double = 160.0,
        fatG: Double,
        targetFatG: Double = 70.0,
        carbsG: Double,
        targetCarbsG: Double = 250.0
    ) {
        self.consumedKcal = consumedKcal
        self.targetKcal = targetKcal
        self.proteinG = proteinG
        self.targetProteinG = targetProteinG
        self.fatG = fatG
        self.targetFatG = targetFatG
        self.carbsG = carbsG
        self.targetCarbsG = targetCarbsG
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Buffer Badge
            HStack {
                Label("Енергетичний баланс та Макроси", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(LifecoreTheme.strainOrange)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "shield.lefthalf.filled")
                    Text("+12.5% Буфер дефіциту")
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(LifecoreTheme.strainOrange.opacity(0.18))
                .foregroundStyle(LifecoreTheme.strainOrange)
                .clipShape(Capsule())
            }

            // Calorie Main Meter
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(consumedKcal))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/ \(Int(targetKcal)) ккал")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                let remaining = max(0, Int(targetKcal - consumedKcal))
                Text("Залишилось: \(remaining) ккал")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(remaining > 0 ? .green : .red)
            }

            // Calorie Progress Bar
            GeometryReader { geo in
                let ratio = min(1.0, consumedKcal / max(1.0, targetKcal))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.orange, Color(red: 1.0, green: 0.35, blue: 0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * ratio, height: 8)
                }
            }
            .frame(height: 8)

            Divider().background(Color.white.opacity(0.08))

            // Three Macro Columns
            HStack(spacing: 14) {
                macroItem(
                    title: "Білок",
                    current: proteinG,
                    target: targetProteinG,
                    color: Color(red: 0.2, green: 0.8, blue: 0.95),
                    unit: "г"
                )

                macroItem(
                    title: "Жири",
                    current: fatG,
                    target: targetFatG,
                    color: Color(red: 1.0, green: 0.8, blue: 0.2),
                    unit: "г"
                )

                macroItem(
                    title: "Вуглеводи",
                    current: carbsG,
                    target: targetCarbsG,
                    color: Color(red: 0.4, green: 0.9, blue: 0.4),
                    unit: "г"
                )
            }
        }
        .lifecoreGlassCard(cornerRadius: 20, borderColor: LifecoreTheme.strainOrange.opacity(0.25))
    }

    private func macroItem(title: String, current: Double, target: Double, color: Color, unit: String) -> some View {
        let ratio = min(1.0, current / max(1.0, target))
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(current))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("/\(Int(target))\(unit)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Small Macro Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                    Capsule().fill(color).frame(width: geo.size.width * ratio, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 2. Dietary Quality & Micronutrients Card

public struct DietaryQualityCard: View {
    public let wholeFoodCount: Int
    public let ultraProcessedCount: Int
    public let totalSodiumMg: Double
    public let totalLeucineG: Double

    public init(
        wholeFoodCount: Int,
        ultraProcessedCount: Int,
        totalSodiumMg: Double,
        totalLeucineG: Double
    ) {
        self.wholeFoodCount = wholeFoodCount
        self.ultraProcessedCount = ultraProcessedCount
        self.totalSodiumMg = totalSodiumMg
        self.totalLeucineG = totalLeucineG
    }

    private var qualityScore: Double {
        let total = wholeFoodCount + ultraProcessedCount
        guard total > 0 else { return 100.0 }
        return (Double(wholeFoodCount) / Double(total)) * 100.0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Якість харчування та біомаркери", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                Text("\(Int(qualityScore))% Цільна їжа")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }

            // Whole food vs ultra processed visual bar
            GeometryReader { geo in
                let total = max(1, wholeFoodCount + ultraProcessedCount)
                let wholeRatio = Double(wholeFoodCount) / Double(total)
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * wholeRatio)
                    Rectangle()
                        .fill(ultraProcessedCount > 0 ? Color.red : Color.white.opacity(0.1))
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)

            Divider().background(Color.white.opacity(0.08))

            // Sodium & Leucine Indicators
            HStack(spacing: 16) {
                // Sodium Indicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.triangle.fill")
                            .foregroundStyle(totalSodiumMg > 2300 ? .orange : .secondary)
                        Text("Натрій")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(Int(totalSodiumMg)) мг")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(totalSodiumMg > 2300 ? .orange : .white)

                    if totalSodiumMg > 2300 {
                        let waterRetentionKg = max(0.0, (totalSodiumMg - 2000.0) / 1000.0 * 0.32)
                        Text("Прогноз затримки води на завтра: +\(String(format: "%.2f", waterRetentionKg)) кг")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.orange)
                    } else {
                        Text("Норма (<2300 мг)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Leucine MPS Indicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.heart.fill")
                            .foregroundStyle(.cyan)
                        Text("Лейцин (MPS)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: "%.1f г", totalLeucineG))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.cyan)

                    Text(totalLeucineG >= 3.0 ? "Поріг MPS досягнуто" : "Ціль ≥ 3.0г для синтезу")
                        .font(.system(size: 9))
                        .foregroundStyle(totalLeucineG >= 3.0 ? .green : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .lifecoreGlassCard()
    }
}

// MARK: - 3. Meal Item Card

public struct MealItemCard: View {
    public let meal: MealRecord
    public let onDelete: () -> Void

    @State private var showingDetails = false

    public init(meal: MealRecord, onDelete: @escaping () -> Void) {
        self.meal = meal
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Name + Time + Kcal
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(formattedTime(meal.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(meal.kcal)) ккал")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)

                    if let w = meal.weightG {
                        Text("\(Int(w)) г")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Macros & Action Row
            HStack(spacing: 16) {
                macroLabel(title: "Б", value: "\(Int(meal.proteinG))г", color: .cyan)
                macroLabel(title: "Ж", value: "\(Int(meal.fatG))г", color: .yellow)
                macroLabel(title: "В", value: "\(Int(meal.carbsG))г", color: .green)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { showingDetails = true }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(8)
                            .background(Color.red.opacity(0.14))
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Tags Chips
            if !meal.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(meal.tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 16)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Видалити страву", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingDetails) {
            MealDetailSheet(meal: meal, onDelete: onDelete)
                .presentationDetents([.medium, .large])
        }
    }

    private func macroLabel(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let (label, color) = tagDisplayInfo(tag)
        return Text(label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func tagDisplayInfo(_ tag: String) -> (String, Color) {
        switch tag {
        case "whole_food": return ("Цільна їжа", .green)
        case "ultra_processed": return ("Ультраперероблена", .red)
        case "solid": return ("Тверда", .blue)
        case "liquid": return ("Рідка", .purple)
        case "fast_absorbing": return ("Швидка", .yellow)
        case "slow_absorbing": return ("Повільна", .teal)
        case "high_sodium": return ("Солона", .orange)
        default: return (tag, .secondary)
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 4. Optimistic Pending Card (<0.2s instant UI)

public struct OptimisticAnalyzingCard: View {
    public let pendingName: String
    public var onCancel: (() -> Void)? = nil

    @State private var isPulsing = false

    public init(pendingName: String, onCancel: (() -> Void)? = nil) {
        self.pendingName = pendingName
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.cyan)
                    Text(pendingName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                Spacer()

                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Аналізую...")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.18))
                        .foregroundStyle(.cyan)
                        .clipShape(Capsule())
                }
            }

            // Shimmer Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .cyan.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: isPulsing ? geo.size.width * 0.6 : 0)
                }
            }
            .frame(height: 6)

            Text("Розпізнаю макроси з +12.5% дефіцитним буфером через Gemini Vision...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - 5. Meal Detail Sheet (Micros & Amino Acids)

public struct MealDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let meal: MealRecord
    public var onDelete: (() -> Void)? = nil

    @State private var showingDeleteConfirm = false

    public init(meal: MealRecord, onDelete: (() -> Void)? = nil) {
        self.meal = meal
        self.onDelete = onDelete
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Основні макроси") {
                    HStack { Text("Калорії (з +12.5% буфером)"); Spacer(); Text("\(Int(meal.kcal)) ккал").bold() }
                    HStack { Text("Білки"); Spacer(); Text(String(format: "%.1f г", meal.proteinG)).bold().foregroundStyle(.cyan) }
                    HStack { Text("Жири"); Spacer(); Text(String(format: "%.1f г", meal.fatG)).bold().foregroundStyle(.yellow) }
                    HStack { Text("Вуглеводи"); Spacer(); Text(String(format: "%.1f г", meal.carbsG)).bold().foregroundStyle(.green) }
                    if let w = meal.weightG {
                        HStack { Text("Оцінена вага (готова страва)"); Spacer(); Text("\(Int(w)) г") }
                    }
                }

                if let micro = meal.micronutrients {
                    Section("Мікронутрієнти") {
                        if let f = micro.fiberG { HStack { Text("Клітковина"); Spacer(); Text(String(format: "%.1f г", f)) } }
                        if let s = micro.sodiumMg { HStack { Text("Натрій"); Spacer(); Text("\(Int(s)) мг") } }
                        if let p = micro.potassiumMg { HStack { Text("Калій"); Spacer(); Text("\(Int(p)) мг") } }
                        if let c = micro.vitaminCMg { HStack { Text("Вітамін C"); Spacer(); Text("\(Int(c)) мг") } }
                        if let fe = micro.ironMg { HStack { Text("Залізо"); Spacer(); Text(String(format: "%.1f мг", fe)) } }
                        if let ca = micro.calciumMg { HStack { Text("Кальцій"); Spacer(); Text("\(Int(ca)) мг") } }
                    }
                }

                if let amino = meal.aminoAcids {
                    Section("Амінокислотний профіль") {
                        if let bcaa = amino.bcaaG { HStack { Text("BCAA"); Spacer(); Text(String(format: "%.1f г", bcaa)).bold() } }
                        if let leu = amino.leucineG { HStack { Text("Лейцин (тригер MPS)"); Spacer(); Text(String(format: "%.1f г", leu)).bold().foregroundStyle(.cyan) } }
                    }
                }

                if let onDelete = onDelete {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Видалити цей прийом їжі")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .confirmationDialog(
                "Видалити цей прийом їжі?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Видалити \"\(meal.name)\"", role: .destructive) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onDelete?()
                    }
                }
                Button("Скасувати", role: .cancel) {}
            } message: {
                Text("Цей запис буде вилучено з вашого щоденника харчування.")
            }
        }
    }
}
