import SwiftUI
import HealthKit

public struct NutritionView: View {
    @StateObject private var storage = MealStorageService.shared
    @ObservedObject private var athleteStore = AthleteProfileStore.shared

    @State private var selectedDietaryDate: String
    @State private var showingInputSheet = false
    @State private var isYesterdayFastMode = false
    @State private var statusToast: String?
    @State private var recentlyDeletedMeal: MealRecord?

    public init() {
        _selectedDietaryDate = State(initialValue: FoodPrompt.dietaryDate(for: Date(), offsetDays: 0))
    }

    private var currentMeals: [MealRecord] {
        storage.meals(for: selectedDietaryDate)
    }

    private var dailyTotals: (kcal: Double, protein: Double, fat: Double, carbs: Double, sodiumMg: Double, leucineG: Double, wholeFoodCount: Int, ultraProcessedCount: Int) {
        storage.dailyTotals(for: selectedDietaryDate)
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Date Navigation & Fast Yesterday Toggle
                        dateNavigationHeader

                        // Fast Action Bar
                        fastActionBar

                        // Daily Macro Summary Card
                        let totals = dailyTotals
                        MacroSummaryCard(
                            consumedKcal: totals.kcal,
                            targetKcal: athleteStore.profile.targetCaloriesKcal,
                            proteinG: totals.protein,
                            targetProteinG: athleteStore.profile.targetProteinG,
                            fatG: totals.fat,
                            targetFatG: athleteStore.profile.targetFatG,
                            carbsG: totals.carbs,
                            targetCarbsG: athleteStore.profile.targetCarbsG
                        )
                        .accessibilityIdentifier("card_nutrition_summary")

                        // Dietary Quality & Micronutrients Card
                        DietaryQualityCard(
                            wholeFoodCount: totals.wholeFoodCount,
                            ultraProcessedCount: totals.ultraProcessedCount,
                            totalSodiumMg: totals.sodiumMg,
                            totalLeucineG: totals.leucineG
                        )

                        // Meals Log List
                        mealsListSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // Undo Toast Floating Banner
                if let deleted = recentlyDeletedMeal {
                    undoBanner(deleted)
                }
            }
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Харчування")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingInputSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LifecoreTheme.statusWarning)
                    }
                    .accessibilityIdentifier("btn_add_meal")
                }
            }
            .sheet(isPresented: $showingInputSheet) {
                FoodInputSheet { imageJpegData, textDescription in
                    processFoodLog(imageJpegData: imageJpegData, textDescription: textDescription)
                }
            }
        }
    }

    // MARK: - Date Navigation

    private var dateNavigationHeader: some View {
        HStack {
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(LifecoreTheme.paperCard)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                    )
                    .foregroundStyle(LifecoreTheme.inkPrimary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(FoodPrompt.formattedDietaryDateHeader(dietaryDate: selectedDietaryDate))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Text("Зміна доби о 04:00")
                    .font(.system(size: 10))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }

            Spacer()

            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(LifecoreTheme.paperCard)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                    )
                    .foregroundStyle(canGoNext ? LifecoreTheme.inkPrimary : LifecoreTheme.inkTertiary.opacity(0.4))
            }
            .disabled(!canGoNext)
        }
        .padding(.horizontal, 4)
    }

    private var canGoNext: Bool {
        let today = FoodPrompt.dietaryDate(for: Date(), offsetDays: 0)
        return selectedDietaryDate < today
    }

    private func previousDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let d = formatter.date(from: selectedDietaryDate),
           let prev = Calendar.current.date(byAdding: .day, value: -1, to: d) {
            selectedDietaryDate = formatter.string(from: prev)
        }
    }

    private func nextDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let d = formatter.date(from: selectedDietaryDate),
           let next = Calendar.current.date(byAdding: .day, value: 1, to: d) {
            selectedDietaryDate = formatter.string(from: next)
        }
    }

    // MARK: - Fast Action Bar

    private var fastActionBar: some View {
        HStack(spacing: 10) {
            Button(action: { showingInputSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(LifecoreTheme.statusWarning)
                    Text("Записати їжу")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                }
                .frame(maxWidth: .infinity)
                .lifecoreGlassCard(cornerRadius: 14, padding: 12)
            }
            .accessibilityIdentifier("btn_add_meal")

            Button(action: toggleYesterdayFastLog) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("За вчора")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isYesterdaySelected ? LifecoreTheme.statusWarning : LifecoreTheme.paperCard)
                .foregroundStyle(isYesterdaySelected ? Color.white : LifecoreTheme.inkPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isYesterdaySelected ? LifecoreTheme.statusWarning : LifecoreTheme.ruleHairline, lineWidth: 1)
                )
            }
        }
    }

    private var isYesterdaySelected: Bool {
        let yesterday = FoodPrompt.dietaryDate(for: Date(), offsetDays: -1)
        return selectedDietaryDate == yesterday
    }

    private func toggleYesterdayFastLog() {
        let today = FoodPrompt.dietaryDate(for: Date(), offsetDays: 0)
        let yesterday = FoodPrompt.dietaryDate(for: Date(), offsetDays: -1)
        if selectedDietaryDate == yesterday {
            selectedDietaryDate = today
        } else {
            selectedDietaryDate = yesterday
        }
    }

    // MARK: - Meals List

    private var mealsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Прийоми їжі за день", systemImage: "fork.knife")
                    .font(.headline)
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Spacer()
                Text("\(currentMeals.count) записів")
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }

            if currentMeals.isEmpty {
                emptyDayView
                    .transition(.opacity)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(currentMeals) { meal in
                        if meal.isOptimisticPending {
                            OptimisticAnalyzingCard(pendingName: meal.name) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    storage.deleteMeal(id: meal.id)
                                }
                            }
                        } else {
                            SwipeableMealCardContainer(onDelete: {
                                deleteMealConfirmed(meal)
                            }) {
                                MealItemCard(meal: meal)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var emptyDayView: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 40))
                .foregroundStyle(LifecoreTheme.inkTertiary)
            Text("Немає записів за цей день")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Text("Натисніть «Записати їжу» або «+» для швидкого розпізнавання калорій.")
                .font(.caption)
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .lifecoreGlassCard(cornerRadius: 16)
    }

    // MARK: - Deletion & Undo Helpers

    private func deleteMealConfirmed(_ meal: MealRecord) {
        let impact = UINotificationFeedbackGenerator()
        impact.prepare()
        impact.notificationOccurred(.success)
        recentlyDeletedMeal = meal

        withAnimation(.easeInOut(duration: 0.25)) {
            storage.deleteMeal(id: meal.id)
        }

        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if recentlyDeletedMeal?.id == meal.id {
                withAnimation {
                    recentlyDeletedMeal = nil
                }
            }
        }
    }

    private func undoBanner(_ meal: MealRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .foregroundStyle(LifecoreTheme.statusDanger)
            Text("Вилучено: \(meal.name)")
                .font(.subheadline)
                .foregroundStyle(LifecoreTheme.inkPrimary)
                .lineLimit(1)

            Spacer()

            Button("Відновити") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    storage.restoreMeal(meal)
                    recentlyDeletedMeal = nil
                }
            }
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(LifecoreTheme.statusWarning)
        }
        .lifecoreGlassCard(cornerRadius: 14, padding: 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Optimistic Food Logging Flow

    private func processFoodLog(imageJpegData: Data?, textDescription: String?) {
        let targetDietaryDate = selectedDietaryDate
        let optimisticTitle = textDescription ?? "Фото страви"

        // 1. Instant optimistic insertion (<0.2s)
        let pendingRecord = storage.insertOptimisticPending(
            name: optimisticTitle,
            dietaryDate: targetDietaryDate
        )

        // 2. Asynchronous background analysis via Gemini
        Task {
            do {
                let nutrition = try await GeminiService.shared.analyzeFood(
                    imageJpegData: imageJpegData,
                    textDescription: textDescription
                )

                // 3. Resolve pending card with finalized macros and tags
                if let resolved = storage.resolvePending(id: pendingRecord.id, nutrition: nutrition) {
                    // 4. Background write-back to Apple HealthKit
                    try? await HealthKitManager.shared.saveMealToHealthKit(meal: resolved)
                }

                // 5. Asynchronous cloud sync to Supabase
                _ = try? await SupabaseSyncService.shared.syncPendingMeals()

                let impact = UINotificationFeedbackGenerator()
                impact.prepare()
                impact.notificationOccurred(.success)

            } catch {
                print("[NutritionView] AI analysis failed with error: \(error.localizedDescription)")
                let fallback = GeminiService.shared.generateOfflineMeal(textDescription: textDescription)
                if let resolved = storage.resolvePending(id: pendingRecord.id, nutrition: fallback) {
                    try? await HealthKitManager.shared.saveMealToHealthKit(meal: resolved)
                }
                _ = try? await SupabaseSyncService.shared.syncPendingMeals()
            }
        }
    }
}

#Preview {
    NutritionView()
        .preferredColorScheme(.light)
}
