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
                    .foregroundStyle(LifecoreTheme.statusWarning)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "shield.lefthalf.filled")
                    Text("+12.5% Буфер дефіциту")
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(LifecoreTheme.statusWarning.opacity(0.14))
                .foregroundStyle(LifecoreTheme.statusWarning)
                .clipShape(Capsule())
            }

            // Calorie Main Meter
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(consumedKcal))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Text("/ \(Int(targetKcal)) ккал")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                Spacer()
                let remaining = max(0, Int(targetKcal - consumedKcal))
                Text("Залишилось: \(remaining) ккал")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(remaining > 0 ? LifecoreTheme.statusOptimal : LifecoreTheme.statusDanger)
            }

            // Calorie Progress Bar
            GeometryReader { geo in
                let ratio = min(1.0, consumedKcal / max(1.0, targetKcal))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LifecoreTheme.paperWell)
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [LifecoreTheme.statusWarning, Color(red: 0.95, green: 0.45, blue: 0.05)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * ratio, height: 8)
                }
            }
            .frame(height: 8)

            LifecoreHairlineDivider()

            // Three Macro Columns
            HStack(spacing: 14) {
                macroItem(
                    title: "Білок",
                    current: proteinG,
                    target: targetProteinG,
                    color: LifecoreTheme.accentTeal,
                    unit: "г"
                )

                macroItem(
                    title: "Жири",
                    current: fatG,
                    target: targetFatG,
                    color: LifecoreTheme.statusWarning,
                    unit: "г"
                )

                macroItem(
                    title: "Вуглеводи",
                    current: carbsG,
                    target: targetCarbsG,
                    color: LifecoreTheme.statusOptimal,
                    unit: "г"
                )
            }
        }
        .lifecoreGlassCard(cornerRadius: 20, borderColor: LifecoreTheme.statusWarning.opacity(0.25))
    }

    private func macroItem(title: String, current: Double, target: Double, color: Color, unit: String) -> some View {
        let ratio = min(1.0, current / max(1.0, target))
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(LifecoreTheme.inkSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(current))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Text("/\(Int(target))\(unit)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }

            // Small Macro Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LifecoreTheme.paperWell).frame(height: 4)
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
                    .foregroundStyle(LifecoreTheme.statusOptimal)
                Spacer()
                Text("\(Int(qualityScore))% Цільна їжа")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(LifecoreTheme.statusOptimal)
            }

            // Whole food vs ultra processed visual bar
            GeometryReader { geo in
                let total = max(1, wholeFoodCount + ultraProcessedCount)
                let wholeRatio = Double(wholeFoodCount) / Double(total)
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(LifecoreTheme.statusOptimal)
                        .frame(width: geo.size.width * wholeRatio)
                    Rectangle()
                        .fill(ultraProcessedCount > 0 ? LifecoreTheme.statusDanger : LifecoreTheme.paperWell)
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)

            LifecoreHairlineDivider()

            // Sodium & Leucine Indicators
            HStack(spacing: 16) {
                // Sodium Indicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.triangle.fill")
                            .foregroundStyle(totalSodiumMg > 2300 ? LifecoreTheme.statusWarning : LifecoreTheme.inkSecondary)
                        Text("Натрій")
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                    Text("\(Int(totalSodiumMg)) мг")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(totalSodiumMg > 2300 ? LifecoreTheme.statusWarning : LifecoreTheme.inkPrimary)

                    if totalSodiumMg > 2300 {
                        let waterRetentionKg = max(0.0, (totalSodiumMg - 2000.0) / 1000.0 * 0.32)
                        Text("Прогноз затримки води на завтра: +\(String(format: "%.2f", waterRetentionKg)) кг")
                            .font(.system(size: 9, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.statusWarning)
                    } else {
                        Text("Норма (<2300 мг)")
                            .font(.system(size: 9))
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Leucine MPS Indicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.heart.fill")
                            .foregroundStyle(LifecoreTheme.accentTeal)
                        Text("Лейцин (MPS)")
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                    Text(String(format: "%.1f г", totalLeucineG))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.accentTeal)

                    Text(totalLeucineG >= 3.0 ? "Поріг MPS досягнуто" : "Ціль ≥ 3.0г для синтезу")
                        .font(.system(size: 9))
                        .foregroundStyle(totalLeucineG >= 3.0 ? LifecoreTheme.statusOptimal : LifecoreTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .lifecoreGlassCard()
    }
}

// MARK: - 3. Swipeable Meal Card Container

public struct SwipeableMealCardContainer<Content: View>: View {
    public let onDelete: () -> Void
    @ViewBuilder public let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isRevealed: Bool = false

    private let buttonWidth: CGFloat = 84

    public init(onDelete: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.onDelete = onDelete
        self.content = content
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            // Destructive Delete Button Revealed on Swipe
            Button(role: .destructive) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.2)) {
                    offset = -240
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onDelete()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 17, weight: .bold))
                    Text("Видалити")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: buttonWidth - 8)
                .frame(maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.red.opacity(0.95), Color(red: 0.8, green: 0.1, blue: 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 2)
            .opacity(offset < -15 ? 1 : 0)

            // Main Card Content
            content()
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isRevealed {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offset = 0
                            isRevealed = false
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            let translation = value.translation.width
                            if isRevealed {
                                let newOffset = -buttonWidth + translation
                                offset = min(0, max(-buttonWidth - 30, newOffset))
                            } else {
                                if translation < 0 {
                                    offset = max(-buttonWidth - 30, translation)
                                }
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            if isRevealed {
                                if translation > 20 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        offset = 0
                                        isRevealed = false
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        offset = -buttonWidth
                                    }
                                }
                            } else {
                                if offset < -35 {
                                    let haptic = UIImpactFeedbackGenerator(style: .light)
                                    haptic.impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        offset = -buttonWidth
                                        isRevealed = true
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        offset = 0
                                        isRevealed = false
                                    }
                                }
                            }
                        }
                )
        }
    }
}

// MARK: - 3.1. Meal Item Card

public struct MealItemCard: View {
    public let meal: MealRecord
    public let onDelete: () -> Void

    @State private var showingDetails = false

    public init(meal: MealRecord, onDelete: @escaping () -> Void = {}) {
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
                        .foregroundStyle(LifecoreTheme.inkPrimary)

                    Text(formattedTime(meal.createdAt))
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(meal.kcal)) ккал")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.statusWarning)

                    if let w = meal.weightG {
                        Text("\(Int(w)) г")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                }
            }

            // Macros & Action Row
            HStack(spacing: 16) {
                macroLabel(title: "Б", value: "\(Int(meal.proteinG))г", color: LifecoreTheme.accentTeal)
                macroLabel(title: "Ж", value: "\(Int(meal.fatG))г", color: LifecoreTheme.statusWarning)
                macroLabel(title: "В", value: "\(Int(meal.carbsG))г", color: LifecoreTheme.statusOptimal)

                Spacer()

                Button(action: { showingDetails = true }) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                        .padding(8)
                        .background(LifecoreTheme.paperWell)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
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
                .monospacedDigit()
                .foregroundStyle(LifecoreTheme.inkPrimary)
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
        case "whole_food": return ("Цільна їжа", LifecoreTheme.statusOptimal)
        case "ultra_processed": return ("Ультраперероблена", LifecoreTheme.statusDanger)
        case "solid": return ("Тверда", LifecoreTheme.accentIndigo)
        case "liquid": return ("Рідка", Color.purple)
        case "fast_absorbing": return ("Швидка", LifecoreTheme.statusWarning)
        case "slow_absorbing": return ("Повільна", LifecoreTheme.accentTeal)
        case "high_sodium": return ("Солона", LifecoreTheme.statusWarning)
        default: return (tag, LifecoreTheme.inkSecondary)
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
                        .tint(LifecoreTheme.accentTeal)
                    Text(pendingName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                }

                Spacer()

                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                } else {
                    Text("Аналізую...")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(LifecoreTheme.accentTeal.opacity(0.14))
                        .foregroundStyle(LifecoreTheme.accentTeal)
                        .clipShape(Capsule())
                }
            }

            // Shimmer Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LifecoreTheme.paperWell)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, LifecoreTheme.accentTeal.opacity(0.4), .clear],
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
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .lifecoreGlassCard(cornerRadius: 14, padding: 14, borderColor: LifecoreTheme.accentTeal.opacity(0.3))
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
                    HStack {
                        Text("Калорії (з +12.5% буфером)")
                        Spacer()
                        Text("\(Int(meal.kcal)) ккал")
                            .bold()
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Білки")
                        Spacer()
                        Text(String(format: "%.1f г", meal.proteinG))
                            .bold()
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.accentTeal)
                    }
                    HStack {
                        Text("Жири")
                        Spacer()
                        Text(String(format: "%.1f г", meal.fatG))
                            .bold()
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.statusWarning)
                    }
                    HStack {
                        Text("Вуглеводи")
                        Spacer()
                        Text(String(format: "%.1f г", meal.carbsG))
                            .bold()
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.statusOptimal)
                    }
                    if let w = meal.weightG {
                        HStack {
                            Text("Оцінена вага (готова страва)")
                            Spacer()
                            Text("\(Int(w)) г")
                                .monospacedDigit()
                        }
                    }
                }

                if let micro = meal.micronutrients {
                    Section("Мікронутрієнти") {
                        if let f = micro.fiberG {
                            HStack {
                                Text("Клітковина")
                                Spacer()
                                Text(String(format: "%.1f г", f)).monospacedDigit()
                            }
                        }
                        if let s = micro.sodiumMg {
                            HStack {
                                Text("Натрій")
                                Spacer()
                                Text("\(Int(s)) мг").monospacedDigit()
                            }
                        }
                        if let p = micro.potassiumMg {
                            HStack {
                                Text("Калій")
                                Spacer()
                                Text("\(Int(p)) мг").monospacedDigit()
                            }
                        }
                        if let c = micro.vitaminCMg {
                            HStack {
                                Text("Вітамін C")
                                Spacer()
                                Text("\(Int(c)) мг").monospacedDigit()
                            }
                        }
                        if let fe = micro.ironMg {
                            HStack {
                                Text("Залізо")
                                Spacer()
                                Text(String(format: "%.1f мг", fe)).monospacedDigit()
                            }
                        }
                        if let ca = micro.calciumMg {
                            HStack {
                                Text("Кальцій")
                                Spacer()
                                Text("\(Int(ca)) мг").monospacedDigit()
                            }
                        }
                    }
                }

                if let amino = meal.aminoAcids {
                    Section("Амінокислотний профіль") {
                        if let bcaa = amino.bcaaG {
                            HStack {
                                Text("BCAA")
                                Spacer()
                                Text(String(format: "%.1f г", bcaa)).bold().monospacedDigit()
                            }
                        }
                        if let leu = amino.leucineG {
                            HStack {
                                Text("Лейцин (тригер MPS)")
                                Spacer()
                                Text(String(format: "%.1f г", leu))
                                    .bold()
                                    .monospacedDigit()
                                    .foregroundStyle(LifecoreTheme.accentTeal)
                            }
                        }
                    }
                }

                if onDelete != nil {
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
                            .foregroundStyle(LifecoreTheme.statusDanger)
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
