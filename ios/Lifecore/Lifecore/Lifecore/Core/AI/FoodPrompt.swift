import Foundation

// MARK: - Nutrition & Meal Models

public struct Micronutrients: Codable, Sendable {
    public let fiberG: Double?
    public let sodiumMg: Double?
    public let potassiumMg: Double?
    public let vitaminCMg: Double?
    public let ironMg: Double?
    public let calciumMg: Double?

    public init(
        fiberG: Double? = nil,
        sodiumMg: Double? = nil,
        potassiumMg: Double? = nil,
        vitaminCMg: Double? = nil,
        ironMg: Double? = nil,
        calciumMg: Double? = nil
    ) {
        self.fiberG = fiberG
        self.sodiumMg = sodiumMg
        self.potassiumMg = potassiumMg
        self.vitaminCMg = vitaminCMg
        self.ironMg = ironMg
        self.calciumMg = calciumMg
    }

    enum CodingKeys: String, CodingKey {
        case fiberG = "fiber_g"
        case sodiumMg = "sodium_mg"
        case potassiumMg = "potassium_mg"
        case vitaminCMg = "vitamin_c_mg"
        case ironMg = "iron_mg"
        case calciumMg = "calcium_mg"
    }
}

public struct AminoAcids: Codable, Sendable {
    public let bcaaG: Double?
    public let leucineG: Double?

    public init(bcaaG: Double? = nil, leucineG: Double? = nil) {
        self.bcaaG = bcaaG
        self.leucineG = leucineG
    }

    enum CodingKeys: String, CodingKey {
        case bcaaG = "bcaa_g"
        case leucineG = "leucine_g"
    }
}

public struct MealNutrition: Codable, Sendable {
    public let mealName: String
    public let kcal: Double
    public let protein: Double
    public let fat: Double
    public let carbs: Double
    public let weightG: Double?
    public let confidence: Double?
    public let tags: [String]
    public let micronutrients: Micronutrients?
    public let aminoAcids: AminoAcids?

    public init(
        mealName: String,
        kcal: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        weightG: Double? = nil,
        confidence: Double? = nil,
        tags: [String] = [],
        micronutrients: Micronutrients? = nil,
        aminoAcids: AminoAcids? = nil
    ) {
        self.mealName = mealName
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.weightG = weightG
        self.confidence = confidence
        self.tags = tags
        self.micronutrients = micronutrients
        self.aminoAcids = aminoAcids
    }

    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case kcal
        case protein
        case fat
        case carbs
        case weightG = "weight_g"
        case confidence
        case tags
        case micronutrients
        case aminoAcids = "amino_acids"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mealName = (try? container.decode(String.self, forKey: .mealName)) ?? "Страва"

        if let val = try? container.decode(Double.self, forKey: .kcal) {
            self.kcal = val
        } else if let val = try? container.decode(Int.self, forKey: .kcal) {
            self.kcal = Double(val)
        } else if let str = try? container.decode(String.self, forKey: .kcal), let val = Double(str) {
            self.kcal = val
        } else {
            self.kcal = 0.0
        }

        if let val = try? container.decode(Double.self, forKey: .protein) {
            self.protein = val
        } else if let val = try? container.decode(Int.self, forKey: .protein) {
            self.protein = Double(val)
        } else if let str = try? container.decode(String.self, forKey: .protein), let val = Double(str) {
            self.protein = val
        } else {
            self.protein = 0.0
        }

        if let val = try? container.decode(Double.self, forKey: .fat) {
            self.fat = val
        } else if let val = try? container.decode(Int.self, forKey: .fat) {
            self.fat = Double(val)
        } else if let str = try? container.decode(String.self, forKey: .fat), let val = Double(str) {
            self.fat = val
        } else {
            self.fat = 0.0
        }

        if let val = try? container.decode(Double.self, forKey: .carbs) {
            self.carbs = val
        } else if let val = try? container.decode(Int.self, forKey: .carbs) {
            self.carbs = Double(val)
        } else if let str = try? container.decode(String.self, forKey: .carbs), let val = Double(str) {
            self.carbs = val
        } else {
            self.carbs = 0.0
        }

        self.weightG = (try? container.decodeIfPresent(Double.self, forKey: .weightG)) ?? (try? container.decodeIfPresent(Int.self, forKey: .weightG)).map(Double.init)
        self.confidence = (try? container.decodeIfPresent(Double.self, forKey: .confidence)) ?? (try? container.decodeIfPresent(Int.self, forKey: .confidence)).map(Double.init)
        self.tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
        self.micronutrients = try? container.decodeIfPresent(Micronutrients.self, forKey: .micronutrients)
        self.aminoAcids = try? container.decodeIfPresent(AminoAcids.self, forKey: .aminoAcids)
    }
}

public struct MealRecord: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let kcal: Double
    public let proteinG: Double
    public let fatG: Double
    public let carbsG: Double
    public let weightG: Double?
    public let confidence: Double?
    public let tags: [String]
    public let micronutrients: Micronutrients?
    public let aminoAcids: AminoAcids?
    public let dietaryDate: String
    public let createdAt: Date
    public var isOptimisticPending: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        kcal: Double,
        proteinG: Double,
        fatG: Double,
        carbsG: Double,
        weightG: Double? = nil,
        confidence: Double? = nil,
        tags: [String] = [],
        micronutrients: Micronutrients? = nil,
        aminoAcids: AminoAcids? = nil,
        dietaryDate: String,
        createdAt: Date = Date(),
        isOptimisticPending: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kcal = kcal
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbsG = carbsG
        self.weightG = weightG
        self.confidence = confidence
        self.tags = tags
        self.micronutrients = micronutrients
        self.aminoAcids = aminoAcids
        self.dietaryDate = dietaryDate
        self.createdAt = createdAt
        self.isOptimisticPending = isOptimisticPending
    }

    public var isWholeFood: Bool { tags.contains("whole_food") }
    public var isUltraProcessed: Bool { tags.contains("ultra_processed") }
    public var isHighSodium: Bool { tags.contains("high_sodium") }
}

// MARK: - Food Prompt & Dietary Date Utilities

public enum FoodPrompt {

    /// System instructions ported from legacy `utils/prompt.js`.
    public static let systemPrompt: String = """
    You are an expert clinical nutritionist AI. Analyze the image OR text description of food.

    CRITICAL ACCURACY RULES:
    1. Scale & Depth: Do not assume standard massive restaurant portions. Analyze the plate size and estimate realistic, moderate weights (e.g., a standard side of rice is usually 100-150g, not 300g).
    2. Cooked vs Raw: For rice, pasta, buckwheat, and oats, ALWAYS calculate macros based on COOKED weight, not dry weight. For meat and poultry, calculate cooked yield.
    3. Realistic Macros & ZERO-CARB BIOCHEMICAL GROUNDING:
       - Pure meats (chicken breast, beef steak, pork, turkey, veal), plain fish (salmon, tuna, cod), seafood, eggs, egg whites, butter, and olive/vegetable oils contain ZERO carbohydrates (0g). NEVER assign carbohydrates to plain meats, fish, eggs, oils, or butter unless breading, flour, honey/sugar glaze, or sweet sauces are explicitly present.
       - Fresh green vegetables (cucumbers, lettuce, spinach, celery) have very minimal carbs (1-3g per 100g).
       - Complex carbohydrates (cooked weight):
         * Cooked white or brown rice: ~28g carbs per 100g.
         * Cooked buckwheat: ~20g carbs per 100g.
         * Cooked pasta: ~25g carbs per 100g.
         * Boiled/baked potatoes: ~17g carbs per 100g.
         * Cooked oatmeal porridge: ~12-15g carbs per 100g.
       - NEVER use raw/dry values (~70-80g/100g) for cooked grains!
    4. Deficit Buffer: Calculate the exact Kcal, then MULTIPLY the total Kcal by 1.125 (add a 12.5% safety buffer: kcal_final = round(kcal_exact * 1.125)). Keep Protein, Fat, and Carbs exact.
    5. Quality Taxonomy (tags): Select 2 to 4 mandatory tags:
       - Choose 'whole_food' (natural, unprocessed/minimally processed) OR 'ultra_processed' (fast food, chips, candy, industrial sausages).
       - Choose 'solid' OR 'liquid' (shakes, smoothies, soups, drinks).
       - Choose 'fast_absorbing' (sweets, refined carbs, liquid whey) OR 'slow_absorbing' (meat, whole grains, eggs).
       - Include 'high_sodium' if the meal contains salty sauces, cured meats, fast food, or pickles.
    6. Micronutrients & Amino Acids Estimation:
       - Provide realistic estimates for key micronutrients: fiber_g, sodium_mg, potassium_mg, vitamin_c_mg, iron_mg, calcium_mg.
       - For meals containing protein, estimate amino_acids: leucine_g and total bcaa_g (leucine + isoleucine + valine).
    7. Language:
       - Output meal_name in Ukrainian (e.g. "Куряче філе з гречкою та салатом").

    Output ONLY a valid JSON object adhering to this schema:
    {
      "meal_name": "Short descriptive name in Ukrainian",
      "kcal": 450,
      "protein": 35,
      "fat": 12,
      "carbs": 50,
      "weight_g": 350,
      "confidence": 85,
      "tags": ["whole_food", "solid", "slow_absorbing"],
      "micronutrients": {
        "fiber_g": 6.5,
        "sodium_mg": 520,
        "potassium_mg": 410,
        "vitamin_c_mg": 12,
        "iron_mg": 2.8,
        "calcium_mg": 85
      },
      "amino_acids": {
        "bcaa_g": 6.5,
        "leucine_g": 2.9
      }
    }
    """

    /// Computes dietary date string (YYYY-MM-DD) with the 04:00 AM shift rule.
    /// Meals between 00:00 and 03:59 belong to the previous day's dietary date.
    public static func dietaryDate(for date: Date = Date(), offsetDays: Int = 0) -> String {
        let calendar = Calendar.current
        // Shift by -4 hours: 03:59 becomes 23:59 of previous day
        let shiftedDate = date.addingTimeInterval(-4.0 * 3600.0)
        let targetDate = calendar.date(byAdding: .day, value: offsetDays, to: shiftedDate) ?? shiftedDate

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: targetDate)
    }

    /// Formats dietary date for user-facing Ukrainian headers (e.g. "Сьогодні, 19 жовтня" or "Вчора, 18 жовтня").
    public static func formattedDietaryDateHeader(dietaryDate: String) -> String {
        let todayStr = self.dietaryDate(for: Date(), offsetDays: 0)
        let yesterdayStr = self.dietaryDate(for: Date(), offsetDays: -1)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dietaryDate) else {
            return dietaryDate
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMMM"
        displayFormatter.locale = Locale(identifier: "uk_UA")
        let dateString = displayFormatter.string(from: date)

        if dietaryDate == todayStr {
            return "Сьогодні, \(dateString)"
        } else if dietaryDate == yesterdayStr {
            return "Вчора, \(dateString)"
        } else {
            return dateString
        }
    }
}
