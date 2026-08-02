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

    /// Fase 3: every item gets tried on every replay pass — a failing item
    /// no longer blocks items queued behind it.
    func testReplayTriesEveryItemAndKeepsFailedOnesWithIncrementedAttempts() async {
        let file = tempDir.appendingPathComponent("queue.json")
        let queue = OfflineQueue(fileURL: file)
        queue.enqueue(makeRequest("a"))
        queue.enqueue(makeRequest("b"))

        let delivered = await queue.replay { request in
            if request.answers.first?.questionID == "b" { throw APIError.transient }
            return AdviceResponse(summary: "ok", recommendations: [], clinicallyApproved: true)
        }

        XCTAssertEqual(delivered.count, 1)
        XCTAssertEqual(queue.pending.count, 1)
        XCTAssertEqual(queue.pending.first?.request.answers.first?.questionID, "b")
        XCTAssertEqual(queue.pending.first?.attempts, 1)
    }

    /// Fase 3: a chronically failing item is dropped after `maxAttempts`
    /// rather than retried forever — every request the app sends is
    /// well-formed, so a repeated failure means "unreachable", not
    /// "invalid", and dropping it doesn't lose data the user can't redo.
    func testReplayDropsItemAfterMaxAttemptsExceeded() async {
        let file = tempDir.appendingPathComponent("queue.json")
        let queue = OfflineQueue(fileURL: file, maxAttempts: 2)
        queue.enqueue(makeRequest("a"))

        _ = await queue.replay { _ in throw APIError.offline }
        XCTAssertEqual(queue.pending.first?.attempts, 1, "First failure: kept for another try")

        _ = await queue.replay { _ in throw APIError.offline }
        XCTAssertTrue(queue.pending.isEmpty, "Second failure hits maxAttempts: dropped")
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

    /// Regression test for fase 2: a withheld (not yet clinically approved)
    /// response must not be cached, or the next load/poll would keep
    /// serving the stale withheld state instead of checking the server again.
    func testWithheldResponseIsNotCached() async {
        struct WithholdingAPI: AdviceAPI {
            func requestAdvice(_ request: AdviceRequest) async throws -> AdviceResponse {
                AdviceResponse(summary: nil, recommendations: nil, clinicallyApproved: false, submissionID: "sub-1")
            }
            func pollForApproval(submissionID: String) async throws -> AdviceResponse {
                AdviceResponse(summary: nil, recommendations: nil, clinicallyApproved: false, submissionID: submissionID)
            }
        }

        let cache = AdviceCache(directory: tempDir)
        let engine = AdviceEngine(api: WithholdingAPI(),
                                  cache: cache,
                                  queue: OfflineQueue(fileURL: tempDir.appendingPathComponent("q.json")),
                                  isOnline: { true })
        let request = makeRequest()

        _ = await engine.advice(for: request)

        XCTAssertNil(cache.response(for: request))
    }

    /// Regression test for the same bug as `testWithheldResponseIsNotCached`,
    /// but on the offline-queue replay path (`flushOfflineQueue`).
    func testFlushOfflineQueueDoesNotCacheWithheldResponses() async {
        let cache = AdviceCache(directory: tempDir)
        let queue = OfflineQueue(fileURL: tempDir.appendingPathComponent("q.json"))
        let request = makeRequest()
        queue.enqueue(request)

        struct WithholdingAPI: AdviceAPI {
            func requestAdvice(_ request: AdviceRequest) async throws -> AdviceResponse {
                AdviceResponse(summary: nil, recommendations: nil, clinicallyApproved: false)
            }
            func pollForApproval(submissionID: String) async throws -> AdviceResponse {
                try await requestAdvice(AdviceRequest(answers: [], scanSharpness: 0))
            }
        }
        let engine = AdviceEngine(api: WithholdingAPI(), cache: cache, queue: queue, isOnline: { true })

        await engine.flushOfflineQueue()

        XCTAssertNil(cache.response(for: request))
    }
}
