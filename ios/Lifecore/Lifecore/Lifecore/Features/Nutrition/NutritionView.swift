import SwiftUI
import HealthKit

public struct NutritionView: View {
    @StateObject private var storage = MealStorageService.shared

    @State private var selectedDietaryDate: String
    @State private var showingInputSheet = false
    @State private var isYesterdayFastMode = false
    @State private var statusToast: String?

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
                        proteinG: totals.protein,
                        fatG: totals.fat,
                        carbsG: totals.carbs
                    )

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
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingInputSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
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
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .foregroundStyle(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(FoodPrompt.formattedDietaryDateHeader(dietaryDate: selectedDietaryDate))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("04:00 AM cutoff")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .foregroundStyle(canGoNext ? .white : .secondary.opacity(0.4))
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
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.orange)
                    Text("Сфотографувати їжу")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 0.1, green: 0.11, blue: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }

            Button(action: toggleYesterdayFastLog) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("За вчора")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isYesterdaySelected ? Color.orange : Color(red: 0.1, green: 0.11, blue: 0.15))
                .foregroundStyle(isYesterdaySelected ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    .foregroundStyle(.white)
                Spacer()
                Text("\(currentMeals.count) записів")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if currentMeals.isEmpty {
                emptyDayView
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(currentMeals) { meal in
                        if meal.isOptimisticPending {
                            OptimisticAnalyzingCard(pendingName: meal.name)
                        } else {
                            MealItemCard(meal: meal) {
                                withAnimation {
                                    storage.deleteMeal(id: meal.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyDayView: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Немає записів за цей день")
                .font(.subheadline)
                .foregroundStyle(.white)
            Text("Натисніть «Сфотографувати їжу» або «+» для швидкого розпізнавання калорій.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                storage.resolvePending(id: pendingRecord.id, nutrition: nutrition)

                // 4. Background write-back to Apple HealthKit
                try? await HealthKitManager.shared.saveMealToHealthKit(
                    name: nutrition.mealName,
                    kcal: nutrition.kcal,
                    proteinG: nutrition.protein,
                    fatG: nutrition.fat,
                    carbsG: nutrition.carbs,
                    sodiumMg: nutrition.micronutrients?.sodiumMg,
                    fiberG: nutrition.micronutrients?.fiberG
                )

                let impact = UINotificationFeedbackGenerator()
                impact.prepare()
                impact.notificationOccurred(.success)

            } catch {
                // If remote fails, fallback heuristic has already resolved
                let fallback = GeminiService.shared.generateOfflineMeal(textDescription: textDescription)
                storage.resolvePending(id: pendingRecord.id, nutrition: fallback)
            }
        }
    }
}

#Preview {
    NutritionView()
        .preferredColorScheme(.dark)
}
