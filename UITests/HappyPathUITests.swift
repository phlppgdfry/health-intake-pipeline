import XCTest

/// One end-to-end journey through the real UI: consent → intake → scan →
/// released advice. The simulator's synthetic frame source replays a blurry →
/// sharp sequence, so the quality gate and auto-capture run deterministically
/// without camera hardware.
final class HappyPathUITests: XCTestCase {
    func testConsentToAdviceJourney() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()

        // Consent: the continue button is disabled until the toggle is on.
        let agree = app.buttons["Agree and continue"]
        XCTAssertTrue(agree.waitForExistence(timeout: 5))
        XCTAssertFalse(agree.isEnabled)
        app.switches.firstMatch.tap()
        XCTAssertTrue(agree.isEnabled)
        agree.tap()

        // Intake: answer all three demo questions.
        for option in ["Skin concern", "A few weeks", "Somewhat"] {
            let button = app.buttons[option]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing intake option \(option)")
            button.tap()
        }

        // Scan: guidance appears while frames are blurry, then auto-capture.
        let useScan = app.buttons["Use this scan"]
        XCTAssertTrue(useScan.waitForExistence(timeout: 15),
                      "Auto-capture did not fire on the synthetic sharp frames")
        useScan.tap()

        // Advice: only shown because the mock response is clinically approved.
        XCTAssertTrue(app.staticTexts["Your personal advice"].waitForExistence(timeout: 10))
    }
}
