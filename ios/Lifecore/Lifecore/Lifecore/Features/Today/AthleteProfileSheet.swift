import SwiftUI

// MARK: - Locale-Aware Numeric Parser

public enum LocaleNumericParser {
    public static func parseDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let direct = Double(trimmed), direct.isFinite {
            return direct
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(normalized), parsed.isFinite {
            return parsed
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        if let num = formatter.number(from: trimmed)?.doubleValue, num.isFinite {
            return num
        }

        return nil
    }

    public static func parseInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = Int(trimmed) { return direct }
        if let d = parseDouble(trimmed), d.isFinite && d == floor(d) {
            return Int(d)
        }
        return nil
    }

    public static func formatDouble(_ value: Double, maxFractionDigits: Int = 1) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.*f", maxFractionDigits, value)
    }
}

// MARK: - Athlete Profile Calibration Sheet

public struct AthleteProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = AthleteProfileStore.shared
    private let coordinator: DailySnapshotCoordinator

    @State private var weightText: String = ""
    @State private var heightText: String = ""
    @State private var ageText: String = ""
    @State private var maxHeartRateText: String = ""
    @State private var restingHeartRateText: String = ""
    @State private var hrvBaselineText: String = ""
    @State private var wristTempBaselineText: String = ""
    @State private var respiratoryRateBaselineText: String = ""
    @State private var spo2BaselineText: String = ""
    @State private var bmrText: String = ""
    @State private var activeMoveGoalText: String = ""
    @State private var targetCaloriesText: String = ""
    @State private var targetProteinText: String = ""
    @State private var targetFatText: String = ""
    @State private var targetCarbsText: String = ""
    @State private var targetSleepText: String = ""
    @State private var hrvMethod: HRVCalculationMethod = .hybridRMSSD

    @State private var validationErrors: [String: String] = [:]
    @State private var formErrorMessage: String? = nil
    @State private var isSaving: Bool = false

    public init(coordinator: DailySnapshotCoordinator? = nil) {
        self.coordinator = coordinator ?? AppEnvironment.current.snapshotCoordinator
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let formError = formErrorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(LifecoreTheme.statusDanger)
                            Text(formError)
                                .font(.subheadline)
                                .foregroundStyle(LifecoreTheme.statusDanger)
                        }
                    }
                }

                // Section 1: Антропометрія
                Section(header: Text("Антропометрія та Пульс").foregroundStyle(LifecoreTheme.inkSecondary)) {
                    inputFieldRow(
                        title: "Вага (кг)",
                        text: $weightText,
                        fieldKey: "weight",
                        keyboard: .decimalPad,
                        accessibilityId: "input_athlete_weight"
                    )

                    inputFieldRow(
                        title: "Зріст (см)",
                        text: $heightText,
                        fieldKey: "height",
                        keyboard: .numberPad
                    )

                    inputFieldRow(
                        title: "Вік (років)",
                        text: $ageText,
                        fieldKey: "age",
                        keyboard: .numberPad
                    )

                    inputFieldRow(
                        title: "Максимальний пульс (HR Max)",
                        text: $maxHeartRateText,
                        fieldKey: "maxHeartRate",
                        keyboard: .numberPad
                    )
                }

                // Section 2: Базові вітальні показники (30-денна норма)
                Section(header: Text("Базові нічні вітальні показники (Apple Watch)").foregroundStyle(LifecoreTheme.inkSecondary)) {
                    inputFieldRow(
                        title: "Базовий RHR (уд/хв)",
                        text: $restingHeartRateText,
                        fieldKey: "restingHeartRate",
                        keyboard: .decimalPad
                    )

                    inputFieldRow(
                        title: "Базовий HRV (мс)",
                        text: $hrvBaselineText,
                        fieldKey: "hrvBaseline",
                        keyboard: .decimalPad
                    )

                    inputFieldRow(
                        title: "Базова темп. зап'ястя (°C)",
                        text: $wristTempBaselineText,
                        fieldKey: "wristTempBaseline",
                        keyboard: .decimalPad
                    )

                    inputFieldRow(
                        title: "Базова частота дихання (дих/хв)",
                        text: $respiratoryRateBaselineText,
                        fieldKey: "respiratoryRateBaseline",
                        keyboard: .decimalPad
                    )

                    inputFieldRow(
                        title: "Базовий SpO₂ (%)",
                        text: $spo2BaselineText,
                        fieldKey: "spo2Baseline",
                        keyboard: .decimalPad
                    )
                }

                // Section 3: Метод розрахунку HRV
                Section(header: Text("Алгоритм розрахунку варіабельності (HRV)").foregroundStyle(LifecoreTheme.inkSecondary)) {
                    Picker("Метод HRV", selection: $hrvMethod) {
                        Text("Гібридний RMSSD (Bevel/Kubios)").tag(HRVCalculationMethod.hybridRMSSD)
                        Text("Apple Health SDNN (Apple Watch)").tag(HRVCalculationMethod.appleSDNN)
                    }
                    .pickerStyle(.menu)

                    Text(hrvMethod == .hybridRMSSD
                         ? "Аналізує інтервали R-R із 20% фільтром артефактів. Найвища чутливість до парасимпатичного тонусу."
                         : "Використовує стандартний 24-годинний SDNN від Apple Health із логарифмічною нормалізацією.")
                    .font(.system(size: 11))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                }

                // Section 4: Енерговитрати та Нутрієнти
                Section(header: Text("Цілі енергії та харчування").foregroundStyle(LifecoreTheme.inkSecondary)) {
                    inputFieldRow(
                        title: "Базовий метаболізм (BMR, ккал)",
                        text: $bmrText,
                        fieldKey: "bmr",
                        keyboard: .numberPad
                    )

                    inputFieldRow(
                        title: "Ціль активної енергії (Move, ккал)",
                        text: $activeMoveGoalText,
                        fieldKey: "activeMoveGoal",
                        keyboard: .numberPad
                    )

                    inputFieldRow(
                        title: "Ціль калорій (з буфером, ккал)",
                        text: $targetCaloriesText,
                        fieldKey: "targetCalories",
                        keyboard: .numberPad
                    )

                    inputFieldRow(
                        title: "Ціль білка (г)",
                        text: $targetProteinText,
                        fieldKey: "targetProtein",
                        keyboard: .numberPad
                    )

                    inputFieldRow(
                        title: "Ціль жирів (г)",
                        text: $targetFatText,
                        fieldKey: "targetFat",
                        keyboard: .numberPad
                    )

                    inputFieldRow(
                        title: "Ціль вуглеводів (г)",
                        text: $targetCarbsText,
                        fieldKey: "targetCarbs",
                        keyboard: .numberPad
                    )

                    inputFieldRow(
                        title: "Цільовий сон (годин)",
                        text: $targetSleepText,
                        fieldKey: "targetSleep",
                        keyboard: .decimalPad
                    )
                }
            }
            .navigationTitle("Профіль атлета")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                        .accessibilityIdentifier("btn_close_profile")
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveProfileIfValid() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(LifecoreTheme.accentPrimary)
                        } else {
                            Text("Зберегти")
                                .fontWeight(.bold)
                                .foregroundStyle(LifecoreTheme.accentPrimary)
                        }
                    }
                    .accessibilityIdentifier("btn_save_profile")
                    .disabled(isSaving)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .lifecoreKeyboardDismissToolbar()
            .accessibilityIdentifier("sheet_athlete_profile")
            .onAppear { loadCurrentProfile() }
        }
    }

    @ViewBuilder
    private func inputFieldRow(
        title: String,
        text: Binding<String>,
        fieldKey: String,
        keyboard: UIKeyboardType,
        accessibilityId: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Spacer()
                TextField(title, text: text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .modifier(OptionalAccessibilityIdentifierModifier(id: accessibilityId))
            }

            if let error = validationErrors[fieldKey] {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.statusDanger)
            }
        }
    }

    private func loadCurrentProfile() {
        let p = store.profile
        weightText = LocaleNumericParser.formatDouble(p.weightKg, maxFractionDigits: 1)
        heightText = LocaleNumericParser.formatDouble(p.heightCm, maxFractionDigits: 0)
        ageText = "\(p.ageYears)"
        maxHeartRateText = LocaleNumericParser.formatDouble(p.maxHeartRateBpm, maxFractionDigits: 0)
        restingHeartRateText = LocaleNumericParser.formatDouble(p.restingHeartRateBaselineBpm, maxFractionDigits: 1)
        hrvBaselineText = LocaleNumericParser.formatDouble(p.hrvBaselineMs, maxFractionDigits: 1)
        wristTempBaselineText = LocaleNumericParser.formatDouble(p.wristTempBaselineCelsius, maxFractionDigits: 2)
        respiratoryRateBaselineText = LocaleNumericParser.formatDouble(p.respiratoryRateBaselineBpm, maxFractionDigits: 1)
        spo2BaselineText = LocaleNumericParser.formatDouble(p.spo2BaselinePct, maxFractionDigits: 1)
        bmrText = LocaleNumericParser.formatDouble(p.bmrKcalPerDay, maxFractionDigits: 0)
        activeMoveGoalText = LocaleNumericParser.formatDouble(p.activeMoveGoalKcal, maxFractionDigits: 0)
        targetCaloriesText = LocaleNumericParser.formatDouble(p.targetCaloriesKcal, maxFractionDigits: 0)
        targetProteinText = LocaleNumericParser.formatDouble(p.targetProteinG, maxFractionDigits: 0)
        targetFatText = LocaleNumericParser.formatDouble(p.targetFatG, maxFractionDigits: 0)
        targetCarbsText = LocaleNumericParser.formatDouble(p.targetCarbsG, maxFractionDigits: 0)
        targetSleepText = LocaleNumericParser.formatDouble(p.targetSleepHours, maxFractionDigits: 1)
        hrvMethod = p.hrvMethod
    }

    private func saveProfileIfValid() async {
        var errors: [String: String] = [:]

        guard let weight = LocaleNumericParser.parseDouble(weightText), weight > 0, weight.isFinite else {
            errors["weight"] = "Введіть додатну вагу (кг)"
            showValidationFailure(errors)
            return
        }

        guard let height = LocaleNumericParser.parseDouble(heightText), height > 0, height.isFinite else {
            errors["height"] = "Введіть додатний зріст (см)"
            showValidationFailure(errors)
            return
        }

        guard let age = LocaleNumericParser.parseInt(ageText), age > 0 else {
            errors["age"] = "Введіть вік більше 0"
            showValidationFailure(errors)
            return
        }

        guard let maxHr = LocaleNumericParser.parseDouble(maxHeartRateText), maxHr > 0, maxHr.isFinite else {
            errors["maxHeartRate"] = "Введіть додатний максимальний пульс"
            showValidationFailure(errors)
            return
        }

        guard let restingHr = LocaleNumericParser.parseDouble(restingHeartRateText), restingHr > 0, restingHr.isFinite else {
            errors["restingHeartRate"] = "Введіть додатний пульс спокою"
            showValidationFailure(errors)
            return
        }

        if maxHr <= restingHr {
            errors["maxHeartRate"] = "HR Max має перевищувати пульс спокою"
            showValidationFailure(errors)
            return
        }

        guard let hrv = LocaleNumericParser.parseDouble(hrvBaselineText), hrv > 0, hrv.isFinite else {
            errors["hrvBaseline"] = "Введіть додатний базовий HRV (мс)"
            showValidationFailure(errors)
            return
        }

        guard let temp = LocaleNumericParser.parseDouble(wristTempBaselineText), temp > 0, temp.isFinite else {
            errors["wristTempBaseline"] = "Введіть додатну температуру (°C)"
            showValidationFailure(errors)
            return
        }

        guard let resp = LocaleNumericParser.parseDouble(respiratoryRateBaselineText), resp > 0, resp.isFinite else {
            errors["respiratoryRateBaseline"] = "Введіть додатну частоту дихання"
            showValidationFailure(errors)
            return
        }

        guard let spo2 = LocaleNumericParser.parseDouble(spo2BaselineText), spo2 > 0, spo2 <= 100, spo2.isFinite else {
            errors["spo2Baseline"] = "Введіть SpO₂ від 1 до 100%"
            showValidationFailure(errors)
            return
        }

        guard let bmr = LocaleNumericParser.parseDouble(bmrText), bmr > 0, bmr.isFinite else {
            errors["bmr"] = "Введіть додатний BMR (ккал)"
            showValidationFailure(errors)
            return
        }

        guard let activeMove = LocaleNumericParser.parseDouble(activeMoveGoalText), activeMove > 0, activeMove.isFinite else {
            errors["activeMoveGoal"] = "Введіть додатну ціль активної енергії"
            showValidationFailure(errors)
            return
        }

        guard let targetCal = LocaleNumericParser.parseDouble(targetCaloriesText), targetCal > 0, targetCal.isFinite else {
            errors["targetCalories"] = "Введіть додатні цільові калорії"
            showValidationFailure(errors)
            return
        }

        guard let protein = LocaleNumericParser.parseDouble(targetProteinText), protein >= 0, protein.isFinite else {
            errors["targetProtein"] = "Введіть невід’ємне значення білка (г)"
            showValidationFailure(errors)
            return
        }

        guard let fat = LocaleNumericParser.parseDouble(targetFatText), fat >= 0, fat.isFinite else {
            errors["targetFat"] = "Введіть невід’ємне значення жирів (г)"
            showValidationFailure(errors)
            return
        }

        guard let carbs = LocaleNumericParser.parseDouble(targetCarbsText), carbs >= 0, carbs.isFinite else {
            errors["targetCarbs"] = "Введіть невід’ємне значення вуглеводів (г)"
            showValidationFailure(errors)
            return
        }

        guard let sleep = LocaleNumericParser.parseDouble(targetSleepText), sleep > 0, sleep <= 24, sleep.isFinite else {
            errors["targetSleep"] = "Введіть сон від 0.5 до 24 годин"
            showValidationFailure(errors)
            return
        }

        validationErrors.removeAll()
        formErrorMessage = nil
        isSaving = true

        var p = store.profile
        p.weightKg = weight
        p.heightCm = height
        p.ageYears = age
        p.maxHeartRateBpm = maxHr
        p.restingHeartRateBaselineBpm = restingHr
        p.hrvBaselineMs = hrv
        p.wristTempBaselineCelsius = temp
        p.respiratoryRateBaselineBpm = resp
        p.spo2BaselinePct = spo2
        p.bmrKcalPerDay = bmr
        p.activeMoveGoalKcal = activeMove
        p.targetCaloriesKcal = targetCal
        p.targetProteinG = protein
        p.targetFatG = fat
        p.targetCarbsG = carbs
        p.targetSleepHours = sleep
        p.hrvMethod = hrvMethod

        store.profile = p
        store.save()
        await coordinator.invalidate(reason: .profileUpdated)
        isSaving = false
        dismiss()
    }

    private func showValidationFailure(_ errors: [String: String]) {
        self.validationErrors = errors
        self.formErrorMessage = "Виправте виділені поля перед збереженням"
    }
}

private struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
