import XCTest
@testable import Lifecore

final class LegacyVerificationTests: XCTestCase {

    func testMathEngineVerificationsPass() {
        let results = MathEngineVerification.runAllVerifications()
        XCTAssertFalse(results.isEmpty, "Verification results must not be empty")

        var failureDescriptions: [String] = []
        for result in results {
            if !result.passed {
                failureDescriptions.append("[\(result.testName)] \(result.details)")
            }
        }

        XCTAssertTrue(
            failureDescriptions.isEmpty,
            "The following MathEngine verifications failed:\n" + failureDescriptions.joined(separator: "\n")
        )
    }
}
