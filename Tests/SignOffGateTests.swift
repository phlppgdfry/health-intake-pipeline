import XCTest
@testable import HealthIntake

final class SignOffGateTests: XCTestCase {
    func testApprovedAdviceIsReleasedIntact() {
        let response = AdviceResponse(summary: "summary",
                                      recommendations: ["one", "two"],
                                      clinicallyApproved: true)
        guard case .released(let advice) = SignOffGate.evaluate(response) else {
            return XCTFail("Approved advice must be released")
        }
        XCTAssertEqual(advice.summary, "summary")
        XCTAssertEqual(advice.recommendations, ["one", "two"])
    }

    func testUnapprovedAdviceIsWithheld() {
        let response = AdviceResponse(summary: "must never be shown",
                                      recommendations: ["hidden"],
                                      clinicallyApproved: false)
        XCTAssertEqual(SignOffGate.evaluate(response), .withheld)
    }
}
