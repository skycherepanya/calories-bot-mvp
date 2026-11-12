import Foundation
@testable import Lifecore

public enum TestFixtures {

    public static func sampleMealRecord(
        id: UUID = UUID(),
        name: String = "Test Oatmeal Bowl",
        kcal: Double = 450.0,
        proteinG: Double = 25.0,
        fatG: Double = 10.0,
        carbsG: Double = 65.0,
        tags: [String] = ["whole_food", "solid"],
        dietaryDate: String = "2026-11-12",
        createdAt: Date = Date()
    ) -> MealRecord {
        MealRecord(
            id: id,
            name: name,
            kcal: kcal,
            proteinG: proteinG,
            fatG: fatG,
            carbsG: carbsG,
            tags: tags,
            dietaryDate: dietaryDate,
            createdAt: createdAt
        )
    }

    public static func sampleMealNutrition(
        mealName: String = "Test Chicken Rice",
        kcal: Double = 600.0,
        protein: Double = 45.0,
        fat: Double = 12.0,
        carbs: Double = 75.0,
        weightG: Double? = 400.0
    ) -> MealNutrition {
        MealNutrition(
            mealName: mealName,
            kcal: kcal,
            protein: protein,
            fat: fat,
            carbs: carbs,
            weightG: weightG,
            tags: ["whole_food", "solid"]
        )
    }

    public static func sampleTelemetryPoints(count: Int = 10, start: Date = Date()) -> [RawTelemetryPoint] {
        (0..<count).map { i in
            RawTelemetryPoint(
                timestamp: start.addingTimeInterval(Double(i * 10)),
                distanceMeters: Double(i * 25),
                heartRateBpm: 140.0 + Double(i % 5),
                altitudeMeters: 100.0 + Double(i * 2),
                cadenceRpm: 165.0
            )
        }
    }

    public static func sampleAssembledDossier() -> AssembledHealthDossier {
        AssembledHealthDossier(
            workoutAnalysis: nil,
            recoveryContext: nil,
            acuteNutrition: .init(),
            adaptiveSensitivitiesSummaryUk: "Адаптація в нормі",
            next24hPrescriptionSummaryUk: "Легке відновне тренування",
            retrievedMemories: []
        )
    }
}
