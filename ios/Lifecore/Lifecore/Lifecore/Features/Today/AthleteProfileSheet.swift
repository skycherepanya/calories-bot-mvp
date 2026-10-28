import SwiftUI

// MARK: - Athlete Profile Calibration Sheet

public struct AthleteProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = AthleteProfileStore.shared

    @State private var weightKg: Double = 78.6
    @State private var heightCm: Double = 181.0
    @State private var ageYears: Int = 28
    @State private var maxHeartRateBpm: Double = 192.0
    @State private var restingHeartRateBaselineBpm: Double = 49.0
    @State private var hrvBaselineMs: Double = 102.0
    @State private var wristTempBaselineCelsius: Double = 36.40
    @State private var respiratoryRateBaselineBpm: Double = 14.2
    @State private var spo2BaselinePct: Double = 97.8
    @State private var bmrKcalPerDay: Double = 1750.0
    @State private var activeMoveGoalKcal: Double = 650.0
    @State private var targetCaloriesKcal: Double = 2150.0
    @State private var targetProteinG: Double = 165.0
    @State private var targetFatG: Double = 70.0
    @State private var targetCarbsG: Double = 215.0
    @State private var targetSleepHours: Double = 7.5
    @State private var hrvMethod: HRVCalculationMethod = .hybridRMSSD

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Антропометрія
                Section(header: Text("Антропометрія та Пульс").foregroundStyle(LifecoreTheme.inkSecondary)) {
                    HStack {
                        Text("Вага (кг)")
                        Spacer()
                        TextField("78.6", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .accessibilityIdentifier("input_athlete_weight")
                    }
                    HStack {
                        Text("Зріст (см)")
                        Spacer()
                        TextField("181", value: $heightCm, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Вік (років)")
                        Spacer()
                        TextField("28", value: $ageYears, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Максимальний пульс (HR Max)")
                        Spacer()
                        TextField("192", value: $maxHeartRateBpm, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                }

                // Section 2: Базові вітальні показники (30-денна норма)
                Section(header: Text("Базові нічні вітальні показники (Apple Watch)").foregroundStyle(LifecoreTheme.inkSecondary)) {
                    HStack {
                        Text("Базовий RHR (уд/хв)")
                        Spacer()
                        TextField("49.0", value: $restingHeartRateBaselineBpm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Базовий HRV (мс)")
                        Spacer()
                        TextField("102.0", value: $hrvBaselineMs, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Базова темп. зап'ястя (°C)")
                        Spacer()
                        TextField("36.40", value: $wristTempBaselineCelsius, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Базова частота дихання (дих/хв)")
                        Spacer()
                        TextField("14.2", value: $respiratoryRateBaselineBpm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Базовий SpO₂ (%)")
                        Spacer()
                        TextField("97.8", value: $spo2BaselinePct, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
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
                    HStack {
                        Text("Базовий метаболізм (BMR, ккал)")
                        Spacer()
                        TextField("1750", value: $bmrKcalPerDay, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Ціль активної енергії (Move, ккал)")
                        Spacer()
                        TextField("650", value: $activeMoveGoalKcal, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Ціль калорій (з буфером, ккал)")
                        Spacer()
                        TextField("2150", value: $targetCaloriesKcal, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Ціль білка (г)")
                        Spacer()
                        TextField("165", value: $targetProteinG, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Ціль жирів (г)")
                        Spacer()
                        TextField("70", value: $targetFatG, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Ціль вуглеводів (г)")
                        Spacer()
                        TextField("215", value: $targetCarbsG, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Цільовий сон (годин)")
                        Spacer()
                        TextField("7.5", value: $targetSleepHours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
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
                    Button("Зберегти") {
                        saveProfile()
                        dismiss()
                    }
                    .accessibilityIdentifier("btn_save_profile")
                    .fontWeight(.bold)
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                }
            }
            .accessibilityIdentifier("sheet_athlete_profile")
            .onAppear { loadCurrentProfile() }
        }
    }

    private func loadCurrentProfile() {
        let p = store.profile
        weightKg = p.weightKg
        heightCm = p.heightCm
        ageYears = p.ageYears
        maxHeartRateBpm = p.maxHeartRateBpm
        restingHeartRateBaselineBpm = p.restingHeartRateBaselineBpm
        hrvBaselineMs = p.hrvBaselineMs
        wristTempBaselineCelsius = p.wristTempBaselineCelsius
        respiratoryRateBaselineBpm = p.respiratoryRateBaselineBpm
        spo2BaselinePct = p.spo2BaselinePct
        bmrKcalPerDay = p.bmrKcalPerDay
        activeMoveGoalKcal = p.activeMoveGoalKcal
        targetCaloriesKcal = p.targetCaloriesKcal
        targetProteinG = p.targetProteinG
        targetFatG = p.targetFatG
        targetCarbsG = p.targetCarbsG
        targetSleepHours = p.targetSleepHours
        hrvMethod = p.hrvMethod
    }

    private func saveProfile() {
        var p = store.profile
        p.weightKg = weightKg
        p.heightCm = heightCm
        p.ageYears = ageYears
        p.maxHeartRateBpm = maxHeartRateBpm
        p.restingHeartRateBaselineBpm = restingHeartRateBaselineBpm
        p.hrvBaselineMs = hrvBaselineMs
        p.wristTempBaselineCelsius = wristTempBaselineCelsius
        p.respiratoryRateBaselineBpm = respiratoryRateBaselineBpm
        p.spo2BaselinePct = spo2BaselinePct
        p.bmrKcalPerDay = bmrKcalPerDay
        p.activeMoveGoalKcal = activeMoveGoalKcal
        p.targetCaloriesKcal = targetCaloriesKcal
        p.targetProteinG = targetProteinG
        p.targetFatG = targetFatG
        p.targetCarbsG = targetCarbsG
        p.targetSleepHours = targetSleepHours
        p.hrvMethod = hrvMethod
        store.profile = p
    }
}
