import XCTest
@testable import HealthIntake

final class EngineTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }

    private func makeRequest(_ id: String = "reason") -> AdviceRequest {
        AdviceRequest(answers: [IntakeAnswer(questionID: id, answer: "Skin concern")],
                      scanSharpness: 120)
    }

    // MARK: Cache

    func testCacheRoundTripsAndSurvivesReload() {
        let request = makeRequest()
        let response = AdviceResponse(summary: "s", recommendations: ["r"], clinicallyApproved: true)

        AdviceCache(directory: tempDir).store(response, for: request)
        // A fresh instance over the same directory must see the stored value.
        XCTAssertEqual(AdviceCache(directory: tempDir).response(for: request), response)
    }

    func testCacheMissForDifferentAnswers() {
        let cache = AdviceCache(directory: tempDir)
        cache.store(AdviceResponse(summary: "s", recommendations: [], clinicallyApproved: true),
                    for: makeRequest("reason"))
        XCTAssertNil(cache.response(for: makeRequest("duration")))
    }

    // MARK: Offline queue

    func testQueuePersistsAndDeduplicates() {
        let file = tempDir.appendingPathComponent("queue.json")
        let queue = OfflineQueue(fileURL: file)
        queue.enqueue(makeRequest())
        queue.enqueue(makeRequest()) // same cacheKey → deduplicated
        queue.enqueue(makeRequest("duration"))
        XCTAssertEqual(queue.pending.count, 2)

        // Simulate app relaunch: a fresh queue reads the same file.
        XCTAssertEqual(OfflineQueue(fileURL: file).pending.count, 2)
    }

    func testReplayStopsAtFirstFailureAndKeepsRemainder() async {
        let file = tempDir.appendingPathComponent("queue.json")
        let queue = OfflineQueue(fileURL: file)
        queue.enqueue(makeRequest("a"))
        queue.enqueue(makeRequest("b"))

        // First request succeeds, second fails → one delivered, one kept.
        var calls = 0
        let delivered = await queue.replay { _ in
            calls += 1
            if calls > 1 { throw APIError.transient }
            return AdviceResponse(summary: "ok", recommendations: [], clinicallyApproved: true)
        }
        XCTAssertEqual(delivered.count, 1)
        XCTAssertEqual(queue.pending.count, 1)
        XCTAssertEqual(queue.pending.first?.answers.first?.questionID, "b")
    }

    // MARK: Engine policy

    func testOfflineRequestIsQueuedNotLost() async {
        let engine = AdviceEngine(api: MockAdviceAPI(),
                                  cache: AdviceCache(directory: tempDir),
                                  queue: OfflineQueue(fileURL: tempDir.appendingPathComponent("q.json")),
                                  isOnline: { false })
        let outcome = await engine.advice(for: makeRequest())
        XCTAssertEqual(outcome, .queuedOffline)
    }

    func testOnlineResponseIsCachedForOfflineReuse() async {
        let cache = AdviceCache(directory: tempDir)
        let request = makeRequest()
        let engine = AdviceEngine(api: MockAdviceAPI(),
                                  cache: cache,
                                  queue: OfflineQueue(fileURL: tempDir.appendingPathComponent("q.json")),
                                  isOnline: { true })

        guard case .advice(let response) = await engine.advice(for: request) else {
            return XCTFail("Expected advice")
        }
        // Now offline: the same request must be served from cache, not queued.
        let offlineEngine = AdviceEngine(api: MockAdviceAPI(failure: .offline),
                                         cache: cache,
                                         queue: OfflineQueue(fileURL: tempDir.appendingPathComponent("q2.json")),
                                         isOnline: { false })
        let outcome = await offlineEngine.advice(for: request)
        XCTAssertEqual(outcome, .advice(response))
    }
}
