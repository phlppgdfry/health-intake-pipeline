import XCTest
@testable import HealthIntake

final class IntakeDraftStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }

    func testSaveAndLoadRoundTrips() {
        let file = tempDir.appendingPathComponent("draft.json")
        let store = IntakeDraftStore(fileURL: file)
        let answers = [IntakeAnswer(questionID: "reason", answer: "Skin concern")]

        store.save(answers: answers, step: .scan)

        // A fresh instance over the same file must see the saved draft —
        // simulates the app being killed and relaunched.
        let reloaded = IntakeDraftStore(fileURL: file)
        XCTAssertEqual(reloaded.draft, .init(answers: answers, step: .scan))
    }

    func testNoDraftWhenNothingSaved() {
        let store = IntakeDraftStore(fileURL: tempDir.appendingPathComponent("draft.json"))
        XCTAssertNil(store.draft)
    }

    func testClearRemovesDraft() {
        let file = tempDir.appendingPathComponent("draft.json")
        let store = IntakeDraftStore(fileURL: file)
        store.save(answers: [IntakeAnswer(questionID: "reason", answer: "Skin concern")], step: .intake)

        store.clear()

        XCTAssertNil(store.draft)
    }
}
