import Foundation

// MARK: - Thread-Safe ISO8601 Cloud Coding

public enum CloudJSONCoding {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatted = date.formatted(
                Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            )
            try container.encode(formatted)
        }
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseISO8601Date(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date string: \(raw)"
            )
        }
        return decoder
    }

    public static func parseISO8601Date(_ raw: String) -> Date? {
        if let fractional = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(raw) {
            return fractional
        }
        if let standard = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(raw) {
            return standard
        }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: raw) { return d }

        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: raw)
    }

    public static func encodeToString<T: Encodable>(_ value: T) -> String {
        guard let data = try? makeEncoder().encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

// MARK: - Lossless JSON Value (for JSONB columns)

public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int64.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSONValue"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .int(let i):
            try container.encode(i)
        case .double(let d):
            try container.encode(d)
        case .string(let s):
            try container.encode(s)
        case .array(let arr):
            try container.encode(arr)
        case .object(let obj):
            try container.encode(obj)
        }
    }

    public static func arrayFromJsonString(_ raw: String) -> [JSONValue] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([JSONValue].self, from: data) else {
            return []
        }
        return decoded
    }

    public static func jsonString(from array: [JSONValue]) -> String {
        guard let data = try? JSONEncoder().encode(array),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }
}

// MARK: - WorkoutAnalysisCloudDTO (006_workout_analyses.sql + R7 revision)

public struct WorkoutAnalysisCloudDTO: Codable, Sendable, Equatable {
    public let id: UUID
    public let userId: Int64
    public let healthkitWorkoutUUID: UUID
    public let workoutType: String
    public let startedAt: Date
    public let distanceKm: Double?
    public let durationMin: Double
    public let avgPaceMinKm: Double?
    public let avgHr: Double?
    public let maxHr: Double?
    public let elevationGainM: Double?
    public let efficiencyFactor: Double?
    public let aerobicDecouplingPct: Double?
    public let splitsJson: [JSONValue]
    public let lapsJson: [JSONValue]
    public let aiCoachReport: String?
    public let revision: Int
    public let createdAt: Date
    public let updatedAt: Date

    public enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case healthkitWorkoutUUID = "healthkit_workout_uuid"
        case workoutType = "workout_type"
        case startedAt = "started_at"
        case distanceKm = "distance_km"
        case durationMin = "duration_min"
        case avgPaceMinKm = "avg_pace_min_km"
        case avgHr = "avg_hr"
        case maxHr = "max_hr"
        case elevationGainM = "elevation_gain_m"
        case efficiencyFactor = "efficiency_factor"
        case aerobicDecouplingPct = "aerobic_decoupling_pct"
        case splitsJson = "splits_json"
        case lapsJson = "laps_json"
        case aiCoachReport = "ai_coach_report"
        case revision
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: UUID,
        userId: Int64,
        healthkitWorkoutUUID: UUID,
        workoutType: String,
        startedAt: Date,
        distanceKm: Double?,
        durationMin: Double,
        avgPaceMinKm: Double?,
        avgHr: Double?,
        maxHr: Double?,
        elevationGainM: Double?,
        efficiencyFactor: Double?,
        aerobicDecouplingPct: Double?,
        splitsJson: [JSONValue],
        lapsJson: [JSONValue],
        aiCoachReport: String?,
        revision: Int = 1,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.healthkitWorkoutUUID = healthkitWorkoutUUID
        self.workoutType = workoutType
        self.startedAt = startedAt
        self.distanceKm = distanceKm
        self.durationMin = durationMin
        self.avgPaceMinKm = avgPaceMinKm
        self.avgHr = avgHr
        self.maxHr = maxHr
        self.elevationGainM = elevationGainM
        self.efficiencyFactor = efficiencyFactor
        self.aerobicDecouplingPct = aerobicDecouplingPct
        self.splitsJson = splitsJson
        self.lapsJson = lapsJson
        self.aiCoachReport = aiCoachReport
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.userId = try container.decode(Int64.self, forKey: .userId)
        self.healthkitWorkoutUUID = try container.decode(UUID.self, forKey: .healthkitWorkoutUUID)
        self.workoutType = try container.decode(String.self, forKey: .workoutType)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
        self.durationMin = try container.decode(Double.self, forKey: .durationMin)
        self.avgPaceMinKm = try container.decodeIfPresent(Double.self, forKey: .avgPaceMinKm)
        self.avgHr = try container.decodeIfPresent(Double.self, forKey: .avgHr)
        self.maxHr = try container.decodeIfPresent(Double.self, forKey: .maxHr)
        self.elevationGainM = try container.decodeIfPresent(Double.self, forKey: .elevationGainM)
        self.efficiencyFactor = try container.decodeIfPresent(Double.self, forKey: .efficiencyFactor)
        self.aerobicDecouplingPct = try container.decodeIfPresent(Double.self, forKey: .aerobicDecouplingPct)
        self.splitsJson = (try? container.decodeIfPresent([JSONValue].self, forKey: .splitsJson)) ?? []
        self.lapsJson = (try? container.decodeIfPresent([JSONValue].self, forKey: .lapsJson)) ?? []
        self.aiCoachReport = try container.decodeIfPresent(String.self, forKey: .aiCoachReport)
        self.revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? self.createdAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(healthkitWorkoutUUID, forKey: .healthkitWorkoutUUID)
        try container.encode(workoutType, forKey: .workoutType)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(distanceKm, forKey: .distanceKm)
        try container.encode(durationMin, forKey: .durationMin)
        try container.encode(avgPaceMinKm, forKey: .avgPaceMinKm)
        try container.encode(avgHr, forKey: .avgHr)
        try container.encode(maxHr, forKey: .maxHr)
        try container.encode(elevationGainM, forKey: .elevationGainM)
        try container.encode(efficiencyFactor, forKey: .efficiencyFactor)
        try container.encode(aerobicDecouplingPct, forKey: .aerobicDecouplingPct)
        try container.encode(splitsJson, forKey: .splitsJson)
        try container.encode(lapsJson, forKey: .lapsJson)
        try container.encode(aiCoachReport, forKey: .aiCoachReport)
        try container.encode(revision, forKey: .revision)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    // MARK: - Lossless Entity Conversion (m <-> km, s <-> min)

    public init(from entity: WorkoutAnalysisEntity, userId: Int64, revision: Int? = nil) {
        self.id = entity.id
        self.userId = userId
        self.healthkitWorkoutUUID = entity.workoutUUID
        self.workoutType = entity.workoutType
        self.startedAt = entity.startedAt
        self.distanceKm = entity.distanceMeters / 1000.0
        self.durationMin = entity.durationSeconds / 60.0
        self.avgPaceMinKm = entity.avgPaceSecPerKm.map { $0 / 60.0 }
        self.avgHr = entity.avgHeartRate
        self.maxHr = entity.maxHeartRate
        self.elevationGainM = entity.elevationGainMeters
        self.efficiencyFactor = entity.efficiencyFactor
        self.aerobicDecouplingPct = entity.cardiacDriftPercentage
        self.splitsJson = JSONValue.arrayFromJsonString(entity.splitsJson)
        self.lapsJson = JSONValue.arrayFromJsonString(entity.lapsJson)
        self.aiCoachReport = entity.aiCoachReport
        self.revision = revision ?? entity.revision
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
    }

    public var distanceMetersLossless: Double {
        (distanceKm ?? 0.0) * 1000.0
    }

    public var durationSecondsLossless: Double {
        durationMin * 60.0
    }

    public var avgPaceSecPerKmLossless: Double? {
        avgPaceMinKm.map { $0 * 60.0 }
    }

    public var splitsJsonString: String {
        JSONValue.jsonString(from: splitsJson)
    }

    public var lapsJsonString: String {
        JSONValue.jsonString(from: lapsJson)
    }

    public func toEntity(syncedToCloud: Bool = true) -> WorkoutAnalysisEntity {
        WorkoutAnalysisEntity(
            id: id,
            workoutUUID: healthkitWorkoutUUID,
            workoutType: workoutType,
            startedAt: startedAt,
            distanceMeters: distanceMetersLossless,
            durationSeconds: durationSecondsLossless,
            avgPaceSecPerKm: avgPaceSecPerKmLossless,
            avgHeartRate: avgHr,
            maxHeartRate: maxHr,
            elevationGainMeters: elevationGainM,
            efficiencyFactor: efficiencyFactor,
            cardiacDriftPercentage: aerobicDecouplingPct,
            splitsJson: splitsJsonString,
            lapsJson: lapsJsonString,
            aiCoachReport: aiCoachReport,
            revision: revision,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncedToCloud: syncedToCloud
        )
    }

    public func apply(to entity: WorkoutAnalysisEntity, syncedToCloud: Bool = true) {
        entity.workoutType = workoutType
        entity.startedAt = startedAt
        entity.distanceMeters = distanceMetersLossless
        entity.durationSeconds = durationSecondsLossless
        entity.avgPaceSecPerKm = avgPaceSecPerKmLossless
        entity.avgHeartRate = avgHr
        entity.maxHeartRate = maxHr
        entity.elevationGainMeters = elevationGainM
        entity.efficiencyFactor = efficiencyFactor
        entity.cardiacDriftPercentage = aerobicDecouplingPct
        entity.splitsJson = splitsJsonString
        entity.lapsJson = lapsJsonString
        entity.aiCoachReport = aiCoachReport
        entity.revision = revision
        entity.updatedAt = updatedAt
        entity.syncedToCloud = syncedToCloud
    }
}

// MARK: - MealCloudDTO (meals table + R7 convergence columns)

public struct MealCloudDTO: Codable, Sendable, Equatable {
    public let id: Int64?
    public let userId: Int64
    public let clientUUID: UUID?
    public let mealName: String
    public let kcal: Double
    public let kcalExact: Double?
    public let bufferVersion: Int
    public let protein: Double
    public let fat: Double
    public let carbs: Double
    public let weightG: Double?
    public let confidence: Double?
    public let tags: [String]
    public let micronutrients: Micronutrients?
    public let aminoAcids: AminoAcids?
    public let dietaryDate: String
    public let revision: Int
    public let provenance: String
    public let isDeleted: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case clientUUID = "client_uuid"
        case mealName = "meal_name"
        case kcal
        case kcalExact = "kcal_exact"
        case bufferVersion = "buffer_version"
        case protein
        case fat
        case carbs
        case weightG = "weight_g"
        case confidence
        case tags
        case micronutrients
        case aminoAcids = "amino_acids"
        case dietaryDate = "dietary_date"
        case revision
        case provenance
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Canonicalizes confidence onto 0...100, converting normalized (0.0..<1.0) values.
    public static func normalizeConfidenceTo100(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        let scaled = (value >= 0.0 && value < 1.0) ? (value * 100.0) : value
        return min(100.0, max(0.0, scaled))
    }

    public init(
        id: Int64? = nil,
        userId: Int64,
        clientUUID: UUID?,
        mealName: String,
        kcal: Double,
        kcalExact: Double? = nil,
        bufferVersion: Int = 1,
        protein: Double,
        fat: Double,
        carbs: Double,
        weightG: Double? = nil,
        confidence: Double? = nil,
        tags: [String] = [],
        micronutrients: Micronutrients? = nil,
        aminoAcids: AminoAcids? = nil,
        dietaryDate: String,
        revision: Int = 1,
        provenance: String = "manual",
        isDeleted: Bool = false,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.clientUUID = clientUUID
        self.mealName = mealName
        self.kcal = kcal
        self.kcalExact = kcalExact
        self.bufferVersion = bufferVersion
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.weightG = weightG
        self.confidence = Self.normalizeConfidenceTo100(confidence)
        self.tags = tags
        self.micronutrients = micronutrients
        self.aminoAcids = aminoAcids
        self.dietaryDate = dietaryDate
        self.revision = revision
        self.provenance = provenance
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int64.self, forKey: .id)
        self.userId = try container.decode(Int64.self, forKey: .userId)
        self.clientUUID = try container.decodeIfPresent(UUID.self, forKey: .clientUUID)
        self.mealName = try container.decode(String.self, forKey: .mealName)
        self.kcal = try container.decode(Double.self, forKey: .kcal)
        self.kcalExact = try container.decodeIfPresent(Double.self, forKey: .kcalExact)
        self.bufferVersion = try container.decodeIfPresent(Int.self, forKey: .bufferVersion) ?? 1
        self.protein = try container.decode(Double.self, forKey: .protein)
        self.fat = try container.decode(Double.self, forKey: .fat)
        self.carbs = try container.decode(Double.self, forKey: .carbs)
        self.weightG = try container.decodeIfPresent(Double.self, forKey: .weightG)
        let rawConfidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        self.confidence = Self.normalizeConfidenceTo100(rawConfidence)
        self.tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []

        if let decodedMicro = try container.decodeIfPresent(Micronutrients.self, forKey: .micronutrients),
           decodedMicro.hasAnyValue {
            self.micronutrients = decodedMicro
        } else {
            self.micronutrients = nil
        }

        if let decodedAmino = try container.decodeIfPresent(AminoAcids.self, forKey: .aminoAcids),
           decodedAmino.hasAnyValue {
            self.aminoAcids = decodedAmino
        } else {
            self.aminoAcids = nil
        }

        self.dietaryDate = try container.decode(String.self, forKey: .dietaryDate)
        self.revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        self.provenance = try container.decodeIfPresent(String.self, forKey: .provenance) ?? "legacy"
        self.isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? self.createdAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(clientUUID, forKey: .clientUUID)
        try container.encode(mealName, forKey: .mealName)
        try container.encode(kcal, forKey: .kcal)
        try container.encode(kcalExact, forKey: .kcalExact)
        try container.encode(bufferVersion, forKey: .bufferVersion)
        try container.encode(protein, forKey: .protein)
        try container.encode(fat, forKey: .fat)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(weightG, forKey: .weightG)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(tags, forKey: .tags)
        try container.encode(micronutrients, forKey: .micronutrients)
        try container.encode(aminoAcids, forKey: .aminoAcids)
        try container.encode(dietaryDate, forKey: .dietaryDate)
        try container.encode(revision, forKey: .revision)
        try container.encode(provenance, forKey: .provenance)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    public func strippingServerIDForWrite() -> MealCloudDTO {
        MealCloudDTO(
            id: nil,
            userId: userId,
            clientUUID: clientUUID,
            mealName: mealName,
            kcal: kcal,
            kcalExact: kcalExact,
            bufferVersion: bufferVersion,
            protein: protein,
            fat: fat,
            carbs: carbs,
            weightG: weightG,
            confidence: confidence,
            tags: tags,
            micronutrients: micronutrients,
            aminoAcids: aminoAcids,
            dietaryDate: dietaryDate,
            revision: revision,
            provenance: provenance,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public init(from entity: MealEntity, userId: Int64) {
        self.init(
            id: entity.remoteId,
            userId: userId,
            clientUUID: entity.clientUUID,
            mealName: entity.name,
            kcal: entity.kcal,
            kcalExact: entity.kcalExact,
            bufferVersion: entity.bufferVersion,
            protein: entity.proteinG,
            fat: entity.fatG,
            carbs: entity.carbsG,
            weightG: entity.weightG,
            confidence: entity.confidence,
            tags: entity.tags,
            micronutrients: entity.micronutrients,
            aminoAcids: entity.aminoAcids,
            dietaryDate: entity.dietaryDate,
            revision: entity.revision,
            provenance: entity.provenance,
            isDeleted: entity.isDeleted,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    public init(from payload: MealSyncPayload, userId: Int64) {
        let micro: Micronutrients? = {
            guard let raw = payload.micronutrientsJson,
                  let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(Micronutrients.self, from: data),
                  decoded.hasAnyValue else {
                return nil
            }
            return decoded
        }()
        let amino: AminoAcids? = {
            guard let raw = payload.aminoAcidsJson,
                  let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(AminoAcids.self, from: data),
                  decoded.hasAnyValue else {
                return nil
            }
            return decoded
        }()
        self.init(
            id: payload.legacyRemoteId,
            userId: userId,
            clientUUID: payload.clientUUID,
            mealName: payload.name,
            kcal: payload.kcal,
            kcalExact: payload.kcalExact,
            bufferVersion: payload.bufferVersion,
            protein: payload.proteinG,
            fat: payload.fatG,
            carbs: payload.carbsG,
            weightG: payload.weightG,
            confidence: payload.confidence,
            tags: payload.tags,
            micronutrients: micro,
            aminoAcids: amino,
            dietaryDate: payload.dietaryDate,
            revision: payload.revision,
            provenance: payload.provenance,
            isDeleted: payload.isDeleted,
            createdAt: payload.createdAt,
            updatedAt: payload.updatedAt
        )
    }

    public func toEntity(syncedToCloud: Bool = true) -> MealEntity {
        let resolvedUUID = clientUUID ?? UUID()
        let microJson: String? = {
            guard let micronutrients, let data = try? JSONEncoder().encode(micronutrients) else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        let aminoJson: String? = {
            guard let aminoAcids, let data = try? JSONEncoder().encode(aminoAcids) else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        return MealEntity(
            id: resolvedUUID,
            clientUUID: resolvedUUID,
            name: mealName,
            kcal: kcal,
            kcalExact: kcalExact,
            bufferVersion: bufferVersion,
            proteinG: protein,
            fatG: fat,
            carbsG: carbs,
            weightG: weightG,
            confidence: confidence,
            tags: tags,
            micronutrientsJson: microJson,
            aminoAcidsJson: aminoJson,
            dietaryDate: dietaryDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: isDeleted ? .cancelled : .confirmed,
            revision: revision,
            provenance: provenance,
            isDeleted: isDeleted,
            isOptimisticPending: false,
            syncedToCloud: syncedToCloud,
            remoteId: id
        )
    }

    public func apply(to entity: MealEntity, syncedToCloud: Bool = true) {
        if let clientUUID {
            entity.clientUUID = clientUUID
        }
        entity.name = mealName
        entity.kcal = kcal
        entity.kcalExact = kcalExact
        entity.bufferVersion = bufferVersion
        entity.proteinG = protein
        entity.fatG = fat
        entity.carbsG = carbs
        entity.weightG = weightG
        entity.confidence = confidence
        entity.tags = tags
        entity.micronutrientsJson = {
            guard let micronutrients, let data = try? JSONEncoder().encode(micronutrients) else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        entity.aminoAcidsJson = {
            guard let aminoAcids, let data = try? JSONEncoder().encode(aminoAcids) else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        entity.dietaryDate = dietaryDate
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.revision = revision
        entity.provenance = provenance
        entity.isDeleted = isDeleted
        entity.lifecycleState = isDeleted ? .cancelled : .confirmed
        entity.isOptimisticPending = false
        entity.syncedToCloud = syncedToCloud
        if let id {
            entity.remoteId = id
        }
    }
}

private extension Micronutrients {
    var hasAnyValue: Bool {
        fiberG != nil || sodiumMg != nil || potassiumMg != nil || vitaminCMg != nil || ironMg != nil || calciumMg != nil
    }
}

private extension AminoAcids {
    var hasAnyValue: Bool {
        bcaaG != nil || leucineG != nil
    }
}

// MARK: - Sync Classification, Conflicts & Results

public enum SyncErrorClassification: String, Codable, Sendable, Equatable {
    case none
    case networkUnavailable
    case unauthorized
    case conflict
    case rateLimited
    case serverError
    case badRequest
}

public struct SyncConflictRecord: Codable, Sendable, Equatable {
    public let entityID: UUID
    public let entityType: SyncEntityType
    public let localRevision: Int
    public let remoteRevision: Int
    public let localPayloadJson: String
    public let remotePayloadJson: String

    public init(
        entityID: UUID,
        entityType: SyncEntityType = .meal,
        localRevision: Int,
        remoteRevision: Int,
        localPayloadJson: String,
        remotePayloadJson: String
    ) {
        self.entityID = entityID
        self.entityType = entityType
        self.localRevision = localRevision
        self.remoteRevision = remoteRevision
        self.localPayloadJson = localPayloadJson
        self.remotePayloadJson = remotePayloadJson
    }
}

public struct SyncResult: Codable, Sendable, Equatable {
    public let succeededOperationIDs: [UUID]
    public let failedOperationIDs: [UUID]
    public let pendingOperationIDs: [UUID]
    public let conflicts: [SyncConflictRecord]
    public let errorClassification: SyncErrorClassification
    public let isCleanSuccess: Bool

    public init(
        succeededOperationIDs: [UUID] = [],
        failedOperationIDs: [UUID] = [],
        pendingOperationIDs: [UUID] = [],
        conflicts: [SyncConflictRecord] = [],
        errorClassification: SyncErrorClassification = .none,
        isCleanSuccess: Bool? = nil
    ) {
        self.succeededOperationIDs = succeededOperationIDs
        self.failedOperationIDs = failedOperationIDs
        self.pendingOperationIDs = pendingOperationIDs
        self.conflicts = conflicts
        self.errorClassification = errorClassification
        self.isCleanSuccess = isCleanSuccess ?? (
            failedOperationIDs.isEmpty
            && pendingOperationIDs.isEmpty
            && conflicts.isEmpty
            && errorClassification == .none
        )
    }
}

public struct SyncPullResult: Sendable, Equatable {
    public let mealsPulled: Int
    public let workoutsPulled: Int
    public let pagesFetched: Int
    public let skippedLocalNewerCount: Int
    public let errorClassification: SyncErrorClassification

    public init(
        mealsPulled: Int = 0,
        workoutsPulled: Int = 0,
        pagesFetched: Int = 0,
        skippedLocalNewerCount: Int = 0,
        errorClassification: SyncErrorClassification = .none
    ) {
        self.mealsPulled = mealsPulled
        self.workoutsPulled = workoutsPulled
        self.pagesFetched = pagesFetched
        self.skippedLocalNewerCount = skippedLocalNewerCount
        self.errorClassification = errorClassification
    }
}

public struct CloudPage<Item: Sendable>: Sendable {
    public let items: [Item]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(items: [Item], nextCursor: String? = nil, hasMore: Bool = false) {
        self.items = items
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}
