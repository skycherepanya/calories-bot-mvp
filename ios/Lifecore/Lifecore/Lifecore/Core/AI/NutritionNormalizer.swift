import Foundation

// MARK: - Type Aliases for Micronutrient & Amino Acid Profiles

public typealias MicronutrientBreakdown = Micronutrients
public typealias AminoAcidProfile = AminoAcids

// MARK: - Normalization Errors

public enum NutritionNormalizationError: Error, LocalizedError, Equatable, Sendable {
    case emptyMealName
    case missingRequiredField(field: String)
    case nonFiniteValue(field: String)
    case negativeValue(field: String, value: Double)
    case invalidConfidence(Double)
    case malformedPayload(String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .emptyMealName:
            return "Meal name cannot be empty."
        case .missingRequiredField(let field):
            return "Missing required nutrition field: '\(field)'."
        case .nonFiniteValue(let field):
            return "Nutrition field '\(field)' must be a finite number (not NaN or Inf)."
        case .negativeValue(let field, let value):
            return "Nutrition field '\(field)' cannot be negative (got \(value))."
        case .invalidConfidence(let value):
            return "Confidence score must be between 0 and 1 (or 0 and 100), got \(value)."
        case .malformedPayload(let details):
            return "Malformed nutrition payload: \(details)"
        case .decodingError(let details):
            return "Failed to decode nutrition payload: \(details)"
        }
    }
}

// MARK: - Raw Nutrition Estimate

/// Unbuffered raw estimate returned by AI vision / text parsing before trust validation and deterministic buffering.
public struct RawNutritionEstimate: Codable, Sendable, Equatable {
    public let mealName: String
    public let kcalExact: Double
    public let protein: Double
    public let fat: Double
    public let carbs: Double
    public let tags: [String]
    public let weightG: Double?
    public let confidence: Double?
    public let micronutrients: MicronutrientBreakdown?
    public let aminoAcids: AminoAcidProfile?

    public init(
        mealName: String,
        kcalExact: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        tags: [String],
        weightG: Double? = nil,
        confidence: Double? = nil,
        micronutrients: MicronutrientBreakdown? = nil,
        aminoAcids: AminoAcidProfile? = nil
    ) {
        self.mealName = mealName
        self.kcalExact = kcalExact
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.tags = tags
        self.weightG = weightG
        self.confidence = confidence
        self.micronutrients = micronutrients
        self.aminoAcids = aminoAcids
    }

    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case mealNameAlt = "mealName"
        case kcalExact = "kcal_exact"
        case kcalExactAlt = "kcalExact"
        case kcalLegacy = "kcal"
        case protein
        case fat
        case carbs
        case tags
        case weightG = "weight_g"
        case weightGAlt = "weightG"
        case confidence
        case micronutrients
        case aminoAcids = "amino_acids"
        case aminoAcidsAlt = "aminoAcids"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 1. mealName: required, non-empty
        let name: String
        if let decoded = try container.decodeIfPresent(String.self, forKey: .mealName) {
            name = decoded
        } else if let decoded = try container.decodeIfPresent(String.self, forKey: .mealNameAlt) {
            name = decoded
        } else {
            throw NutritionNormalizationError.missingRequiredField(field: "meal_name")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NutritionNormalizationError.emptyMealName
        }
        self.mealName = name

        // 2. kcalExact: required
        self.kcalExact = try Self.decodeNumericValue(
            from: container,
            primaryKey: .kcalExact,
            altKeys: [.kcalExactAlt, .kcalLegacy],
            fieldName: "kcal_exact"
        )

        // 3. protein: required
        self.protein = try Self.decodeNumericValue(
            from: container,
            primaryKey: .protein,
            altKeys: [],
            fieldName: "protein"
        )

        // 4. fat: required
        self.fat = try Self.decodeNumericValue(
            from: container,
            primaryKey: .fat,
            altKeys: [],
            fieldName: "fat"
        )

        // 5. carbs: required
        self.carbs = try Self.decodeNumericValue(
            from: container,
            primaryKey: .carbs,
            altKeys: [],
            fieldName: "carbs"
        )

        // 6. tags: required
        if let decodedTags = try container.decodeIfPresent([String].self, forKey: .tags) {
            self.tags = decodedTags
        } else {
            throw NutritionNormalizationError.missingRequiredField(field: "tags")
        }

        // 7. weightG: optional
        self.weightG = try Self.decodeOptionalNumericValue(
            from: container,
            primaryKey: .weightG,
            altKeys: [.weightGAlt],
            fieldName: "weight_g"
        )

        // 8. confidence: optional
        self.confidence = try Self.decodeOptionalNumericValue(
            from: container,
            primaryKey: .confidence,
            altKeys: [],
            fieldName: "confidence"
        )

        // 9. micronutrients: optional
        self.micronutrients = try container.decodeIfPresent(MicronutrientBreakdown.self, forKey: .micronutrients)

        // 10. aminoAcids: optional
        if let amino = try container.decodeIfPresent(AminoAcidProfile.self, forKey: .aminoAcids) {
            self.aminoAcids = amino
        } else {
            self.aminoAcids = try container.decodeIfPresent(AminoAcidProfile.self, forKey: .aminoAcidsAlt)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mealName, forKey: .mealName)
        try container.encode(kcalExact, forKey: .kcalExact)
        try container.encode(protein, forKey: .protein)
        try container.encode(fat, forKey: .fat)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(weightG, forKey: .weightG)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(micronutrients, forKey: .micronutrients)
        try container.encodeIfPresent(aminoAcids, forKey: .aminoAcids)
    }

    // MARK: - Decoding Helpers

    private static func decodeNumericValue(
        from container: KeyedDecodingContainer<CodingKeys>,
        primaryKey: CodingKeys,
        altKeys: [CodingKeys],
        fieldName: String
    ) throws -> Double {
        var doubleVal: Double?
        var foundKey = false

        for key in [primaryKey] + altKeys {
            if container.contains(key) {
                foundKey = true
                if let d = try? container.decode(Double.self, forKey: key) {
                    doubleVal = d
                    break
                } else if let i = try? container.decode(Int.self, forKey: key) {
                    doubleVal = Double(i)
                    break
                } else if let s = try? container.decode(String.self, forKey: key) {
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if trimmed == "nan" || trimmed == "+nan" || trimmed == "-nan" {
                        throw NutritionNormalizationError.nonFiniteValue(field: fieldName)
                    } else if trimmed == "inf" || trimmed == "+inf" || trimmed == "-inf" || trimmed == "infinity" || trimmed == "+infinity" || trimmed == "-infinity" {
                        throw NutritionNormalizationError.nonFiniteValue(field: fieldName)
                    } else if let parsed = Double(trimmed) {
                        doubleVal = parsed
                        break
                    } else {
                        throw NutritionNormalizationError.malformedPayload("Field '\(fieldName)' has non-numeric string value '\(s)'")
                    }
                } else {
                    throw NutritionNormalizationError.malformedPayload("Field '\(fieldName)' has invalid type")
                }
            }
        }

        guard foundKey else {
            throw NutritionNormalizationError.missingRequiredField(field: fieldName)
        }

        guard let val = doubleVal else {
            throw NutritionNormalizationError.missingRequiredField(field: fieldName)
        }

        guard !val.isNaN && !val.isInfinite else {
            throw NutritionNormalizationError.nonFiniteValue(field: fieldName)
        }

        guard val >= 0 else {
            throw NutritionNormalizationError.negativeValue(field: fieldName, value: val)
        }

        return val
    }

    private static func decodeOptionalNumericValue(
        from container: KeyedDecodingContainer<CodingKeys>,
        primaryKey: CodingKeys,
        altKeys: [CodingKeys],
        fieldName: String
    ) throws -> Double? {
        for key in [primaryKey] + altKeys {
            if container.contains(key) {
                if (try? container.decodeNil(forKey: key)) == true {
                    return nil
                }
                if let d = try? container.decode(Double.self, forKey: key) {
                    guard !d.isNaN && !d.isInfinite else {
                        throw NutritionNormalizationError.nonFiniteValue(field: fieldName)
                    }
                    guard d >= 0 else {
                        throw NutritionNormalizationError.negativeValue(field: fieldName, value: d)
                    }
                    return d
                } else if let i = try? container.decode(Int.self, forKey: key) {
                    let d = Double(i)
                    guard d >= 0 else {
                        throw NutritionNormalizationError.negativeValue(field: fieldName, value: d)
                    }
                    return d
                } else if let s = try? container.decode(String.self, forKey: key) {
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if trimmed == "nan" || trimmed == "+nan" || trimmed == "-nan" ||
                        trimmed == "inf" || trimmed == "+inf" || trimmed == "-inf" ||
                        trimmed == "infinity" || trimmed == "+infinity" || trimmed == "-infinity" {
                        throw NutritionNormalizationError.nonFiniteValue(field: fieldName)
                    } else if let parsed = Double(trimmed) {
                        guard parsed >= 0 else {
                            throw NutritionNormalizationError.negativeValue(field: fieldName, value: parsed)
                        }
                        return parsed
                    } else {
                        throw NutritionNormalizationError.malformedPayload("Field '\(fieldName)' has non-numeric string value '\(s)'")
                    }
                } else {
                    throw NutritionNormalizationError.malformedPayload("Field '\(fieldName)' has invalid type")
                }
            }
        }
        return nil
    }
}

// MARK: - Nutrition Normalizer

public enum NutritionNormalizer {

    /// Standard known quality taxonomy tags
    public static let standardQualityTags: Set<String> = [
        "whole_food", "ultra_processed",
        "solid", "liquid",
        "fast_absorbing", "slow_absorbing",
        "high_sodium"
    ]

    /// Decodes raw estimate from JSON Data, applying strict validation.
    public static func decode(from data: Data) throws -> RawNutritionEstimate {
        do {
            return try JSONDecoder().decode(RawNutritionEstimate.self, from: data)
        } catch let err as NutritionNormalizationError {
            throw err
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, _):
                throw NutritionNormalizationError.missingRequiredField(field: key.stringValue)
            case .valueNotFound(_, let context):
                let field = context.codingPath.last?.stringValue ?? "unknown"
                throw NutritionNormalizationError.missingRequiredField(field: field)
            case .dataCorrupted(let context):
                throw NutritionNormalizationError.malformedPayload(context.debugDescription)
            case .typeMismatch(_, let context):
                let field = context.codingPath.last?.stringValue ?? "unknown"
                throw NutritionNormalizationError.malformedPayload("Type mismatch at '\(field)'")
            @unknown default:
                throw NutritionNormalizationError.decodingError(decodingError.localizedDescription)
            }
        } catch {
            throw NutritionNormalizationError.decodingError(error.localizedDescription)
        }
    }

    /// Decodes and normalizes raw JSON data into a verified `MealNutrition`.
    public static func decodeAndNormalize(from data: Data) throws -> MealNutrition {
        let raw = try decode(from: data)
        return try normalize(raw)
    }

    /// Normalizes raw nutrition estimate:
    /// - Validates non-negative, finite numbers.
    /// - Validates non-empty required fields.
    /// - Applies the +12.5% deficit buffer EXACTLY ONCE to calories: `round(raw.kcalExact * 1.125)`.
    /// - Preserves exact protein, fat, carbs (no scaling).
    /// - Validates quality tags semantically.
    public static func normalize(_ raw: RawNutritionEstimate) throws -> MealNutrition {
        // 1. Required field: mealName non-empty
        let trimmedName = raw.mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw NutritionNormalizationError.emptyMealName
        }

        // 2. Validate finite & non-negative numbers
        guard !raw.kcalExact.isNaN && !raw.kcalExact.isInfinite else {
            throw NutritionNormalizationError.nonFiniteValue(field: "kcal_exact")
        }
        guard raw.kcalExact >= 0 else {
            throw NutritionNormalizationError.negativeValue(field: "kcal_exact", value: raw.kcalExact)
        }

        guard !raw.protein.isNaN && !raw.protein.isInfinite else {
            throw NutritionNormalizationError.nonFiniteValue(field: "protein")
        }
        guard raw.protein >= 0 else {
            throw NutritionNormalizationError.negativeValue(field: "protein", value: raw.protein)
        }

        guard !raw.fat.isNaN && !raw.fat.isInfinite else {
            throw NutritionNormalizationError.nonFiniteValue(field: "fat")
        }
        guard raw.fat >= 0 else {
            throw NutritionNormalizationError.negativeValue(field: "fat", value: raw.fat)
        }

        guard !raw.carbs.isNaN && !raw.carbs.isInfinite else {
            throw NutritionNormalizationError.nonFiniteValue(field: "carbs")
        }
        guard raw.carbs >= 0 else {
            throw NutritionNormalizationError.negativeValue(field: "carbs", value: raw.carbs)
        }

        // 3. Validate optional weight
        if let weight = raw.weightG {
            guard !weight.isNaN && !weight.isInfinite else {
                throw NutritionNormalizationError.nonFiniteValue(field: "weight_g")
            }
            guard weight >= 0 else {
                throw NutritionNormalizationError.negativeValue(field: "weight_g", value: weight)
            }
        }

        // 4. Validate and bound optional confidence
        let normalizedConfidence: Double?
        if let conf = raw.confidence {
            guard !conf.isNaN && !conf.isInfinite else {
                throw NutritionNormalizationError.nonFiniteValue(field: "confidence")
            }
            guard conf >= 0 && conf <= 100 else {
                throw NutritionNormalizationError.invalidConfidence(conf)
            }
            // Normalize 0...100 range to 0.0...1.0
            normalizedConfidence = (conf > 1.0) ? (conf / 100.0) : conf
        } else {
            normalizedConfidence = nil
        }

        // 5. Apply the required deficit safety buffer (+12.5%) EXACTLY ONCE
        let bufferedKcal = round(raw.kcalExact * 1.125)

        // 6. Semantic tag normalization
        let validatedTags = normalizeTags(raw.tags)

        return MealNutrition(
            mealName: trimmedName,
            kcal: bufferedKcal,
            protein: raw.protein,
            fat: raw.fat,
            carbs: raw.carbs,
            weightG: raw.weightG,
            confidence: normalizedConfidence,
            tags: validatedTags,
            micronutrients: raw.micronutrients,
            aminoAcids: raw.aminoAcids
        )
    }

    /// Validates and normalizes tags semantically:
    /// - Lowercases and trims whitespace.
    /// - Deduplicates preserving first occurrence order.
    /// - Resolves mutual exclusivity (e.g. whole_food vs ultra_processed).
    /// - Preserves valid custom tags and handles empty arrays cleanly.
    public static func normalizeTags(_ tags: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        for rawTag in tags {
            let cleaned = rawTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !cleaned.isEmpty else { continue }
            if !seen.contains(cleaned) {
                seen.insert(cleaned)
                result.append(cleaned)
            }
        }

        // Semantic mutual exclusivity resolution
        // 1. whole_food vs ultra_processed -> if both specified, ultra_processed takes precedence
        if seen.contains("whole_food") && seen.contains("ultra_processed") {
            result.removeAll { $0 == "whole_food" }
        }

        // 2. solid vs liquid -> preserve first specified
        if seen.contains("solid") && seen.contains("liquid") {
            if let firstIdx = result.firstIndex(where: { $0 == "solid" || $0 == "liquid" }) {
                let kept = result[firstIdx]
                let discarded = (kept == "solid") ? "liquid" : "solid"
                result.removeAll { $0 == discarded }
            }
        }

        // 3. fast_absorbing vs slow_absorbing -> preserve first specified
        if seen.contains("fast_absorbing") && seen.contains("slow_absorbing") {
            if let firstIdx = result.firstIndex(where: { $0 == "fast_absorbing" || $0 == "slow_absorbing" }) {
                let kept = result[firstIdx]
                let discarded = (kept == "fast_absorbing") ? "slow_absorbing" : "fast_absorbing"
                result.removeAll { $0 == discarded }
            }
        }

        return result
    }
}
