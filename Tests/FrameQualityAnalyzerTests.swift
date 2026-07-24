import XCTest
@testable import HealthIntake

final class FrameQualityAnalyzerTests: XCTestCase {
    private let analyzer = FrameQualityAnalyzer()

    func testSharpCheckerboardIsUsable() throws {
        let frame = try XCTUnwrap(SyntheticFrame.make(sharp: true))
        let quality = analyzer.analyze(frame)
        XCTAssertTrue(quality.isSharp, "High-contrast checkerboard should score sharp, got \(quality.sharpness)")
        XCTAssertTrue(quality.isWellLit)
        XCTAssertTrue(quality.isUsable)
        XCTAssertNil(quality.guidance)
    }

    func testFlatGradientReadsAsBlurred() throws {
        let frame = try XCTUnwrap(SyntheticFrame.make(sharp: false))
        let quality = analyzer.analyze(frame)
        XCTAssertFalse(quality.isSharp, "Edge-free gradient should score blurred, got \(quality.sharpness)")
        XCTAssertFalse(quality.isUsable)
        XCTAssertEqual(quality.guidance, "Hold the phone still")
    }

    func testDarkFrameGetsLightingGuidance() {
        // Dark but sharp: tiny bright checkerboard on black would be unusual,
        // so build quality directly to pin the guidance priority contract.
        let quality = CaptureQuality(sharpness: 200, brightness: 0.05)
        XCTAssertTrue(quality.isSharp)
        XCTAssertFalse(quality.isWellLit)
        XCTAssertEqual(quality.guidance, "Find more light")
    }

    func testOverexposedFrameGetsGuidance() {
        let quality = CaptureQuality(sharpness: 200, brightness: 0.95)
        XCTAssertEqual(quality.guidance, "Too bright — avoid direct light")
    }

    func testBlurGuidanceWinsOverLighting() {
        // Both problems present → the instruction the user can act on first.
        let quality = CaptureQuality(sharpness: 5, brightness: 0.05)
        XCTAssertEqual(quality.guidance, "Hold the phone still")
    }
}
