import XCTest
@testable import HealthIntake

@MainActor
final class AppFlowTests: XCTestCase {
    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeEngine() -> AdviceEngine {
        AdviceEngine(api: MockAdviceAPI(),
                    cache: AdviceCache(directory: tempDir.appendingPathComponent("cache")),
                    queue: OfflineQueue(fileURL: tempDir.appendingPathComponent("queue.json")))
    }

    /// Fase 3: an interrupted intake resumes instead of restarting.
    func testResumesDraftedIntakeWhenConsentAlreadyGiven() {
        let consentStore = ConsentStore(defaults: defaults)
        consentStore.accept()
        let draftStore = IntakeDraftStore(fileURL: tempDir.appendingPathComponent("draft.json"))
        let answers = [IntakeAnswer(questionID: "reason", answer: "Skin concern")]
        draftStore.save(answers: answers, step: .scan)

        let flow = AppFlow(consentStore: consentStore, engine: makeEngine(), draftStore: draftStore)

        XCTAssertEqual(flow.step, .scan)
        XCTAssertEqual(flow.intakeAnswers, answers)
    }

    func testNoDraftStartsAtIntake() {
        let consentStore = ConsentStore(defaults: defaults)
        consentStore.accept()
        let draftStore = IntakeDraftStore(fileURL: tempDir.appendingPathComponent("draft.json"))

        let flow = AppFlow(consentStore: consentStore, engine: makeEngine(), draftStore: draftStore)

        XCTAssertEqual(flow.step, .intake)
        XCTAssertEqual(flow.intakeAnswers, [])
    }

    func testRevokeConsentClearsDraft() {
        let consentStore = ConsentStore(defaults: defaults)
        consentStore.accept()
        let draftFile = tempDir.appendingPathComponent("draft.json")
        let draftStore = IntakeDraftStore(fileURL: draftFile)
        draftStore.save(answers: [IntakeAnswer(questionID: "reason", answer: "Skin concern")], step: .intake)

        let flow = AppFlow(consentStore: consentStore, engine: makeEngine(), draftStore: draftStore)
        flow.revokeConsent()

        XCTAssertNil(IntakeDraftStore(fileURL: draftFile).draft)
    }

    func testAdvanceToAdviceClearsDraft() {
        let consentStore = ConsentStore(defaults: defaults)
        consentStore.accept()
        let draftFile = tempDir.appendingPathComponent("draft.json")
        let draftStore = IntakeDraftStore(fileURL: draftFile)

        let flow = AppFlow(consentStore: consentStore, engine: makeEngine(), draftStore: draftStore)
        flow.recordIntakeAnswers([IntakeAnswer(questionID: "reason", answer: "Skin concern")])
        flow.advanceToScan()
        XCTAssertNotNil(IntakeDraftStore(fileURL: draftFile).draft)

        flow.advanceToAdvice(with: ScanCapture(
            image: makeTestImage(),
            quality: CaptureQuality(sharpness: 100, brightness: 0.5),
            capturedAt: Date()))

        XCTAssertNil(IntakeDraftStore(fileURL: draftFile).draft)
    }

    private func makeTestImage() -> CGImage {
        let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        return context.makeImage()!
    }
}
