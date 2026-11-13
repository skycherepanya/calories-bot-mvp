import SwiftUI
import HealthKit

public struct NutritionView: View {
    @Environment(\.appEnvironment) private var env
    @StateObject private var viewModel: NutritionViewModel
    @ObservedObject private var athleteStore = AthleteProfileStore.shared

    @State private var showingInputSheet = false
    @State private var showingQualityDetails = false
    @State private var selectedMealForDetails: MealRecord? = nil

    public init(viewModel: NutritionViewModel? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(wrappedValue: NutritionViewModel())
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Date Navigation Header (DietaryDay 04:00 AM shift)
                        dateNavigationHeader

                        // Fast Action Bar
                        fastActionBar

                        // Daily Macro Summary Card
                        let totals = viewModel.dailyTotals
                        MacroSummaryCard(
                            consumedKcal: totals.kcal,
                            targetKcal: athleteStore.profile.targetCaloriesKcal,
                            proteinG: totals.protein,
                            targetProteinG: athleteStore.profile.targetProteinG,
                            fatG: totals.fat,
                            targetFatG: athleteStore.profile.targetFatG,
                            carbsG: totals.carbs,
                            targetCarbsG: athleteStore.profile.targetCarbsG,
                            mealCount: viewModel.confirmedMeals.count
                        )
                        .accessibilityIdentifier("card_nutrition_summary")

                        // Quality & Micronutrients in a clean DisclosureGroup
                        qualityDisclosureGroup(totals: totals)

                        // Meals Log List
                        mealsListSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 88)
                }

                // Error Banner Toast if mutation failed
                if let err = viewModel.errorMessage, viewModel.captureState == .idle {
                    errorToast(err)
                }
            }
            .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
            .navigationTitle("Харчування")
            .accessibilityIdentifier("screen_nutrition")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingInputSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LifecoreTheme.statusWarning)
                    }
                    .accessibilityIdentifier("btn_add_meal")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
            }
            .sheet(isPresented: $showingInputSheet) {
                FoodInputSheet { imageJpegData, textDescription in
                    showingInputSheet = false
                    Task {
                        // Brief pause to allow sheet transition before presenting review
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        await viewModel.analyze(
                            text: textDescription ?? "",
                            imageData: imageJpegData
                        )
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.captureState != .idle },
                set: { if !$0 { viewModel.cancelCapture() } }
            )) {
                MealReviewSheet(viewModel: viewModel)
            }
            .sheet(item: $selectedMealForDetails) { meal in
                MealDetailSheet(meal: meal, onDelete: {
                    viewModel.deleteMealSafely(meal)
                })
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Date Navigation Header

    private var dateNavigationHeader: some View {
        HStack {
            Button(action: { viewModel.previousDay() }) {
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
                Text(FoodPrompt.formattedDietaryDateHeader(dietaryDate: viewModel.selectedDietaryDate))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Text("Зміна доби о 04:00 (інтервал 04:00 – 04:00)")
                    .font(.system(size: 10))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }

            Spacer()

            Button(action: { viewModel.nextDay() }) {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(LifecoreTheme.paperCard)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                    )
                    .foregroundStyle(viewModel.canGoNext ? LifecoreTheme.inkPrimary : LifecoreTheme.inkTertiary.opacity(0.4))
            }
            .disabled(!viewModel.canGoNext)
        }
        .padding(.horizontal, 4)
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

            Button(action: { viewModel.toggleYesterdayFastLog() }) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("За вчора")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(viewModel.isYesterdaySelected ? LifecoreTheme.statusWarning : LifecoreTheme.paperCard)
                .foregroundStyle(viewModel.isYesterdaySelected ? Color.white : LifecoreTheme.inkPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(viewModel.isYesterdaySelected ? LifecoreTheme.statusWarning : LifecoreTheme.ruleHairline, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Quality & Micronutrients Disclosure Group

    private func qualityDisclosureGroup(totals: (kcal: Double, protein: Double, fat: Double, carbs: Double, sodiumMg: Double, leucineG: Double, wholeFoodCount: Int, ultraProcessedCount: Int)) -> some View {
        DisclosureGroup(
            isExpanded: $showingQualityDetails,
            content: {
                DietaryQualityCard(
                    wholeFoodCount: totals.wholeFoodCount,
                    ultraProcessedCount: totals.ultraProcessedCount,
                    totalSodiumMg: totals.sodiumMg,
                    totalLeucineG: totals.leucineG
                )
                .padding(.top, 8)
            },
            label: {
                HStack {
                    Label("Якість та мікронутрієнти", systemImage: "sparkles")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                    Spacer()
                    let totalItems = totals.wholeFoodCount + totals.ultraProcessedCount
                    if totalItems > 0 {
                        let score = Int((Double(totals.wholeFoodCount) / Double(totalItems)) * 100)
                        Text("\(score)% Цільна їжа")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(LifecoreTheme.statusOptimal)
                    } else {
                        Text("Деталі")
                            .font(.caption2)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                }
            }
        )
        .lifecoreGlassCard(cornerRadius: 16, padding: 14)
    }

    // MARK: - Meals List Section

    private var mealsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Прийоми їжі за день", systemImage: "fork.knife")
                    .font(.headline)
                    .foregroundStyle(LifecoreTheme.inkPrimary)
                Spacer()
                Text("\(viewModel.confirmedMeals.count) записів")
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }

            if let deleted = viewModel.recentlyDeletedMeal {
                undoBanner(deleted)
            }

            if viewModel.isDayEmpty {
                emptyDayView
                    .transition(.opacity)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.confirmedMeals) { meal in
                        SwipeableMealCardContainer(onDelete: {
                            viewModel.deleteMealSafely(meal)
                        }) {
                            MealItemCard(
                                meal: meal,
                                onDelete: {
                                    viewModel.deleteMealSafely(meal)
                                },
                                onShowDetails: {
                                    selectedMealForDetails = meal
                                }
                            )
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
            Text("Ще немає підтверджених страв")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifecoreTheme.inkPrimary)
            Text("Натисніть «Записати їжу» для розпізнавання порції з детермінованим +12.5% буфером.")
                .font(.caption)
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .lifecoreGlassCard(cornerRadius: 16)
    }

    // MARK: - Undo & Error Banners

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
                    viewModel.undoDeleteSafely()
                }
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(LifecoreTheme.statusWarning)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
            .accessibilityIdentifier("meal_undo")
        }
        .lifecoreGlassCard(cornerRadius: 14, padding: 12)
        .transition(.opacity)
    }

    private func errorToast(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(LifecoreTheme.statusDanger)
            Text(message)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(LifecoreTheme.statusDanger)
                .lineLimit(2)
            Spacer()
            Button(action: { viewModel.errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
        }
        .lifecoreGlassCard(cornerRadius: 14, padding: 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    NutritionView()
        .preferredColorScheme(.light)
}
