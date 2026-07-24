import XCTest
@testable import HealthIntake

final class FramingTests: XCTestCase {
    // MARK: Verdict → usability contract

    func testFramingProblemsBlockCapture() {
        for framing: CaptureQuality.Framing in [.noSubject, .tooFar, .offCenter] {
            let quality = CaptureQuality(sharpness: 200, brightness: 0.5, framing: framing)
            XCTAssertFalse(quality.isUsable, "\(framing) must block capture")
            XCTAssertNotNil(quality.guidance)
        }
    }

    func testOkAndNotRequiredFramingAllowCapture() {
        for framing: CaptureQuality.Framing in [.ok, .notRequired] {
            let quality = CaptureQuality(sharpness: 200, brightness: 0.5, framing: framing)
            XCTAssertTrue(quality.isUsable)
            XCTAssertNil(quality.guidance)
        }
    }

    func testGuidancePriorityBlurBeforeFramingBeforeLight() {
        // Blur wins over everything: you can't judge framing on a smeared frame.
        let blurred = CaptureQuality(sharpness: 5, brightness: 0.05, framing: .noSubject)
        XCTAssertEqual(blurred.guidance, "Hold the phone still")

        // Sharp but no subject: framing wins over lighting.
        let unframed = CaptureQuality(sharpness: 200, brightness: 0.05, framing: .noSubject)
        XCTAssertEqual(unframed.guidance, "Position your face in the frame")
    }

    // MARK: Vision integration

    func testVisionFindsNoFaceOnTestCard() throws {
        // The synthetic checkerboard passes sharpness and exposure but must
        // never pass the face gate — proving the three checks are independent.
        let frame = try XCTUnwrap(SyntheticFrame.make(sharp: true))
        XCTAssertEqual(FaceFramingChecker().check(frame), .noSubject)
    }
}
