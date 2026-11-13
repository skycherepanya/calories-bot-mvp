import XCTest
@testable import Lifecore

// MARK: - Mock URL Protocol for Network Contract Testing

final class MockNutritionURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Nutrition Contract Tests

final class NutritionContractTests: XCTestCase {

    override func tearDown() {
        MockNutritionURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - 1. Single Buffer Applied Once

    func testSingleBufferAppliedOnce() throws {
        // 200 kcal exact -> 225 kcal buffered (+12.5%), macros unchanged
        let raw = RawNutritionEstimate(
            mealName: "Яйця",
            kcalExact: 200,
            protein: 12.25,
            fat: 10.5,
            carbs: 0,
            tags: ["whole_food", "solid"]
        )

        let meal = try NutritionNormalizer.normalize(raw)

        // Buffer formula: round(raw.kcalExact * 1.125) -> round(200 * 1.125) = 225
        XCTAssertEqual(meal.kcal, 225.0, accuracy: 0.001)
        XCTAssertEqual(meal.protein, 12.25, accuracy: 0.001)
        XCTAssertEqual(meal.fat, 10.5, accuracy: 0.001)
        XCTAssertEqual(meal.carbs, 0.0, accuracy: 0.001)
        XCTAssertEqual(meal.mealName, "Яйця")
        XCTAssertEqual(meal.tags, ["whole_food", "solid"])

        // Additional rounding checks:
        // 100 kcal -> round(112.5) = 113 kcal
        let raw100 = RawNutritionEstimate(mealName: "Перекус", kcalExact: 100, protein: 5, fat: 2, carbs: 10, tags: ["solid"])
        let meal100 = try NutritionNormalizer.normalize(raw100)
        XCTAssertEqual(meal100.kcal, 113.0, accuracy: 0.001)

        // 400 kcal -> round(450.0) = 450 kcal
        let raw400 = RawNutritionEstimate(mealName: "Обід", kcalExact: 400, protein: 30, fat: 12, carbs: 45, tags: ["whole_food"])
        let meal400 = try NutritionNormalizer.normalize(raw400)
        XCTAssertEqual(meal400.kcal, 450.0, accuracy: 0.001)

        // Macros are strictly unscaled
        XCTAssertEqual(meal400.protein, 30.0, accuracy: 0.001)
        XCTAssertEqual(meal400.fat, 12.0, accuracy: 0.001)
        XCTAssertEqual(meal400.carbs, 45.0, accuracy: 0.001)
    }

    // MARK: - 2. Reject Empty or Malformed JSON

    func testRejectEmptyOrMalformedJSON() throws {
        // A. Reject empty JSON object: {}
        let emptyJSON = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: emptyJSON)) { error in
            guard let normError = error as? NutritionNormalizationError else {
                XCTFail("Expected NutritionNormalizationError, got: \(error)")
                return
            }
            if case .missingRequiredField = normError {
                // Expected
            } else {
                XCTFail("Expected missingRequiredField, got: \(normError)")
            }
        }

        // B. Reject missing required fields
        let missingKcal = """
        {"meal_name": "Салат", "protein": 10, "fat": 5, "carbs": 20, "tags": ["solid"]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: missingKcal))

        let missingProtein = """
        {"meal_name": "Салат", "kcal_exact": 200, "fat": 5, "carbs": 20, "tags": ["solid"]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: missingProtein))

        let missingFat = """
        {"meal_name": "Салат", "kcal_exact": 200, "protein": 10, "carbs": 20, "tags": ["solid"]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: missingFat))

        let missingCarbs = """
        {"meal_name": "Салат", "kcal_exact": 200, "protein": 10, "fat": 5, "tags": ["solid"]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: missingCarbs))

        let missingTags = """
        {"meal_name": "Салат", "kcal_exact": 200, "protein": 10, "fat": 5, "carbs": 20}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: missingTags))

        // C. Reject empty meal name
        let emptyMealNameJSON = """
        {"meal_name": "   ", "kcal_exact": 200, "protein": 10, "fat": 5, "carbs": 20, "tags": ["solid"]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: emptyMealNameJSON)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .emptyMealName)
        }

        let rawEmptyName = RawNutritionEstimate(mealName: "  ", kcalExact: 200, protein: 10, fat: 5, carbs: 20, tags: ["solid"])
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawEmptyName)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .emptyMealName)
        }

        // D. Reject NaN values
        let nanJSON = """
        {"meal_name": "Салат", "kcal_exact": "nan", "protein": 10, "fat": 5, "carbs": 20, "tags": ["solid"]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: nanJSON)) { error in
            guard case .nonFiniteValue(let field) = (error as? NutritionNormalizationError) else {
                XCTFail("Expected nonFiniteValue, got \(error)")
                return
            }
            XCTAssertEqual(field, "kcal_exact")
        }

        let rawNaN = RawNutritionEstimate(mealName: "Салат", kcalExact: .nan, protein: 10, fat: 5, carbs: 20, tags: ["solid"])
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawNaN)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .nonFiniteValue(field: "kcal_exact"))
        }

        // E. Reject Inf values
        let infJSON = """
        {"meal_name": "Салат", "kcal_exact": "inf", "protein": 10, "fat": 5, "carbs": 20, "tags": ["solid"]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: infJSON)) { error in
            guard case .nonFiniteValue(let field) = (error as? NutritionNormalizationError) else {
                XCTFail("Expected nonFiniteValue, got \(error)")
                return
            }
            XCTAssertEqual(field, "kcal_exact")
        }

        let rawInf = RawNutritionEstimate(mealName: "Салат", kcalExact: .infinity, protein: 10, fat: 5, carbs: 20, tags: ["solid"])
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawInf)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .nonFiniteValue(field: "kcal_exact"))
        }

        // F. Reject negative numbers
        let rawNegativeKcal = RawNutritionEstimate(mealName: "Салат", kcalExact: -200, protein: 10, fat: 5, carbs: 20, tags: ["solid"])
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawNegativeKcal)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .negativeValue(field: "kcal_exact", value: -200))
        }

        let rawNegativeProtein = RawNutritionEstimate(mealName: "Салат", kcalExact: 200, protein: -10, fat: 5, carbs: 20, tags: ["solid"])
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawNegativeProtein)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .negativeValue(field: "protein", value: -10))
        }

        let rawNegativeFat = RawNutritionEstimate(mealName: "Салат", kcalExact: 200, protein: 10, fat: -5, carbs: 20, tags: ["solid"])
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawNegativeFat)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .negativeValue(field: "fat", value: -5))
        }

        let rawNegativeCarbs = RawNutritionEstimate(mealName: "Салат", kcalExact: 200, protein: 10, fat: 5, carbs: -20, tags: ["solid"])
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawNegativeCarbs)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .negativeValue(field: "carbs", value: -20))
        }

        let rawNegativeWeight = RawNutritionEstimate(mealName: "Салат", kcalExact: 200, protein: 10, fat: 5, carbs: 20, tags: ["solid"], weightG: -50)
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawNegativeWeight)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .negativeValue(field: "weight_g", value: -50))
        }

        // G. Reject invalid confidence
        let rawInvalidConf = RawNutritionEstimate(mealName: "Салат", kcalExact: 200, protein: 10, fat: 5, carbs: 20, tags: ["solid"], confidence: 150)
        XCTAssertThrowsError(try NutritionNormalizer.normalize(rawInvalidConf)) { error in
            XCTAssertEqual(error as? NutritionNormalizationError, .invalidConfidence(150))
        }

        // H. Reject malformed non-JSON data
        let malformed = "not a valid json string".data(using: .utf8)!
        XCTAssertThrowsError(try NutritionNormalizer.decode(from: malformed))
    }

    // MARK: - 3. Tag Validation

    func testTagValidation() throws {
        // A. Preserves valid standard tags
        let standardTags = ["whole_food", "solid", "slow_absorbing", "high_sodium"]
        let raw = RawNutritionEstimate(
            mealName: "Корисна страва",
            kcalExact: 300,
            protein: 20,
            fat: 10,
            carbs: 30,
            tags: standardTags
        )
        let meal = try NutritionNormalizer.normalize(raw)
        XCTAssertEqual(meal.tags, standardTags)

        // B. Handles custom tags
        let customTags = ["whole_food", "keto", "gluten_free", "organic"]
        let rawCustom = RawNutritionEstimate(
            mealName: "Кето страва",
            kcalExact: 400,
            protein: 25,
            fat: 30,
            carbs: 5,
            tags: customTags
        )
        let mealCustom = try NutritionNormalizer.normalize(rawCustom)
        XCTAssertEqual(mealCustom.tags, ["whole_food", "keto", "gluten_free", "organic"])

        // C. Handles empty tags cleanly
        let rawEmptyTags = RawNutritionEstimate(
            mealName: "Страва без тегів",
            kcalExact: 250,
            protein: 15,
            fat: 8,
            carbs: 25,
            tags: []
        )
        let mealEmptyTags = try NutritionNormalizer.normalize(rawEmptyTags)
        XCTAssertEqual(mealEmptyTags.tags, [])

        // D. Trims whitespace, lowercases, and deduplicates preserving order
        let noisyTags = ["  Whole_Food  ", "SOLID", "whole_food", "  ", "KETO"]
        let normalized = NutritionNormalizer.normalizeTags(noisyTags)
        XCTAssertEqual(normalized, ["whole_food", "solid", "keto"])

        // E. Resolves mutual exclusivity:
        // whole_food vs ultra_processed -> ultra_processed wins
        let contradictoryTags1 = ["whole_food", "solid", "ultra_processed"]
        let resolved1 = NutritionNormalizer.normalizeTags(contradictoryTags1)
        XCTAssertEqual(resolved1, ["solid", "ultra_processed"])

        // solid vs liquid -> first wins
        let contradictoryTags2 = ["solid", "liquid", "whole_food"]
        let resolved2 = NutritionNormalizer.normalizeTags(contradictoryTags2)
        XCTAssertEqual(resolved2, ["solid", "whole_food"])

        let contradictoryTags3 = ["liquid", "solid", "whole_food"]
        let resolved3 = NutritionNormalizer.normalizeTags(contradictoryTags3)
        XCTAssertEqual(resolved3, ["liquid", "whole_food"])

        // fast_absorbing vs slow_absorbing -> first wins
        let contradictoryTags4 = ["fast_absorbing", "slow_absorbing"]
        let resolved4 = NutritionNormalizer.normalizeTags(contradictoryTags4)
        XCTAssertEqual(resolved4, ["fast_absorbing"])
    }

    // MARK: - 4. Error Contracts & Network Mocking

    private func makeMockGeminiService() -> (GeminiService, URLSession) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockNutritionURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = GeminiService(session: session)
        service.setApiKey("test-gemini-key")
        return (service, session)
    }

    func testErrorContractsHTTP401() async {
        let (service, _) = makeMockGeminiService()

        MockNutritionURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"error": {"code": 401, "message": "API key not valid. Please pass a valid API key."}}
            """.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await service.analyzeFood(textDescription: "Вівсянка")
            XCTFail("Expected HTTP 401 error, but analyzeFood succeeded unexpectedly")
        } catch let GeminiError.httpError(statusCode, message) {
            XCTAssertEqual(statusCode, 401)
            XCTAssertTrue(message.contains("API key not valid"))
        } catch {
            XCTFail("Expected GeminiError.httpError, got: \(error)")
        }
    }

    func testErrorContractsHTTP429() async {
        let (service, _) = makeMockGeminiService()

        MockNutritionURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"error": {"code": 429, "message": "Resource has been exhausted (e.g. check quota)."}}
            """.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await service.analyzeFood(textDescription: "Вівсянка")
            XCTFail("Expected HTTP 429 error, but analyzeFood succeeded unexpectedly")
        } catch let GeminiError.httpError(statusCode, message) {
            XCTAssertEqual(statusCode, 429)
            XCTAssertTrue(message.contains("Resource has been exhausted"))
        } catch {
            XCTFail("Expected GeminiError.httpError, got: \(error)")
        }
    }

    func testErrorContractsHTTP500() async {
        let (service, _) = makeMockGeminiService()

        MockNutritionURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"error": {"code": 500, "message": "Internal error encountered."}}
            """.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await service.analyzeFood(textDescription: "Вівсянка")
            XCTFail("Expected HTTP 500 error, but analyzeFood succeeded unexpectedly")
        } catch let GeminiError.httpError(statusCode, message) {
            XCTAssertEqual(statusCode, 500)
            XCTAssertTrue(message.contains("Internal error encountered"))
        } catch {
            XCTFail("Expected GeminiError.httpError, got: \(error)")
        }
    }

    func testErrorContractsTimeout() async {
        let (service, _) = makeMockGeminiService()

        MockNutritionURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await service.analyzeFood(textDescription: "Вівсянка")
            XCTFail("Expected timeout error, but analyzeFood succeeded unexpectedly")
        } catch let urlError as URLError {
            XCTAssertEqual(urlError.code, .timedOut)
        } catch {
            XCTFail("Expected URLError.timedOut, got: \(error)")
        }
    }

    func testErrorContractsMissingAPIKey() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockNutritionURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = GeminiService(session: session)
        service.setApiKey("") // Explicitly empty API key

        do {
            _ = try await service.analyzeFood(textDescription: "Вівсянка")
            XCTFail("Expected missingApiKey error, but analyzeFood succeeded unexpectedly")
        } catch GeminiError.missingApiKey {
            // Expected
        } catch {
            XCTFail("Expected GeminiError.missingApiKey, got: \(error)")
        }
    }

    func testErrorContractsMalformedJSONFromAI() async {
        let (service, _) = makeMockGeminiService()

        // AI returns malformed JSON candidate
        MockNutritionURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
              "candidates": [
                {
                  "content": {
                    "parts": [
                      {"text": "{ this is definitely not valid json }"}
                    ]
                  }
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await service.analyzeFood(textDescription: "Вівсянка")
            XCTFail("Expected decoding failure, but analyzeFood succeeded unexpectedly")
        } catch {
            // Verify typed error thrown rather than synthetic meal fabricated
            XCTAssertTrue(
                error is GeminiError || error is NutritionNormalizationError || error is DecodingError,
                "Must throw typed error on malformed JSON payload, got \(error)"
            )
        }
    }

    func testErrorContractsEmptyResponseFromAI() async {
        let (service, _) = makeMockGeminiService()

        // AI returns candidate with empty text
        MockNutritionURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
              "candidates": [
                {
                  "content": {
                    "parts": [
                      {"text": ""}
                    ]
                  }
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await service.analyzeFood(textDescription: "Вівсянка")
            XCTFail("Expected emptyResponse error, but analyzeFood succeeded unexpectedly")
        } catch GeminiError.emptyResponse {
            // Expected
        } catch {
            XCTFail("Expected GeminiError.emptyResponse, got: \(error)")
        }
    }
}
