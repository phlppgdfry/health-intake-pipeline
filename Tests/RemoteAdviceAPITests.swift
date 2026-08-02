import XCTest
@testable import HealthIntake

/// Intercepts every request made through a session configured with this
/// protocol registered, so `RemoteAdviceAPI` can be tested without a live
/// server. Set `stub` per test just before making the call.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var stub: (Data, HTTPURLResponse)?
    nonisolated(unsafe) static var error: URLError?
    nonisolated(unsafe) static var lastRequestBody: Data?
    nonisolated(unsafe) static var lastRequestHeaders: [String: String]?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequestHeaders = request.allHTTPHeaderFields
        Self.lastRequestBody = request.httpBodyStream.map { stream -> Data in
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: bufferSize)
                if read > 0 { data.append(buffer, count: read) }
            }
            return data
        } ?? request.httpBody

        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let (data, response) = Self.stub else {
            XCTFail("No stub configured")
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class RemoteAdviceAPITests: XCTestCase {
    private var api: RemoteAdviceAPI!
    private let baseURL = URL(string: "https://example.invalid")!

    override func setUpWithError() throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        api = RemoteAdviceAPI(baseURL: baseURL, session: URLSession(configuration: config))
        StubURLProtocol.stub = nil
        StubURLProtocol.error = nil
        StubURLProtocol.lastRequestBody = nil
        StubURLProtocol.lastRequestHeaders = nil
    }

    private func makeRequest() -> AdviceRequest {
        AdviceRequest(answers: [IntakeAnswer(questionID: "reason", answer: "Skin concern")],
                      scanSharpness: 42)
    }

    private func respond(status: Int, json: String) {
        let response = HTTPURLResponse(url: baseURL, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
        StubURLProtocol.stub = (json.data(using: .utf8)!, response)
    }

    func testRequestAdviceEncodesAnswersAndSharpness() async throws {
        respond(status: 201, json: """
        {"id":"abc-123","status":"PendingReview","summary":null,"recommendations":null,"clinicallyApproved":false}
        """)

        let response = try await api.requestAdvice(makeRequest())

        XCTAssertEqual(response.submissionID, "abc-123")
        XCTAssertFalse(response.clinicallyApproved)
        XCTAssertNil(response.summary)
        XCTAssertNil(response.recommendations)

        let body = try JSONSerialization.jsonObject(with: StubURLProtocol.lastRequestBody!) as? [String: Any]
        let answers = body?["answers"] as? [[String: Any]]
        XCTAssertEqual(answers?.first?["questionID"] as? String, "reason")
        XCTAssertEqual(body?["scanSharpness"] as? Double, 42)
    }

    func testRequestAdviceSendsStableIdempotencyKeyForSameContent() async throws {
        respond(status: 201, json: """
        {"id":"abc-123","status":"PendingReview","summary":null,"recommendations":null,"clinicallyApproved":false}
        """)
        _ = try await api.requestAdvice(makeRequest())
        let firstKey = StubURLProtocol.lastRequestHeaders?["Idempotency-Key"]
        XCTAssertNotNil(firstKey)

        respond(status: 201, json: """
        {"id":"abc-123","status":"PendingReview","summary":null,"recommendations":null,"clinicallyApproved":false}
        """)
        _ = try await api.requestAdvice(makeRequest())
        let secondKey = StubURLProtocol.lastRequestHeaders?["Idempotency-Key"]

        XCTAssertEqual(firstKey, secondKey, "Same intake content must produce the same idempotency key")

        respond(status: 201, json: """
        {"id":"xyz-789","status":"PendingReview","summary":null,"recommendations":null,"clinicallyApproved":false}
        """)
        _ = try await api.requestAdvice(AdviceRequest(
            answers: [IntakeAnswer(questionID: "reason", answer: "Something else")], scanSharpness: 42))
        let differentKey = StubURLProtocol.lastRequestHeaders?["Idempotency-Key"]

        XCTAssertNotEqual(firstKey, differentKey, "Different intake content must produce a different key")
    }

    func testPollForApprovalDecodesReleasedAdvice() async throws {
        respond(status: 200, json: """
        {"id":"abc-123","status":"Approved","summary":"Take it easy.","recommendations":["Rest","Hydrate"],"clinicallyApproved":true}
        """)

        let response = try await api.pollForApproval(submissionID: "abc-123")

        XCTAssertTrue(response.clinicallyApproved)
        XCTAssertEqual(response.summary, "Take it easy.")
        XCTAssertEqual(response.recommendations, ["Rest", "Hydrate"])
    }

    func testConnectionFailureMapsToOffline() async {
        StubURLProtocol.error = URLError(.notConnectedToInternet)

        do {
            _ = try await api.requestAdvice(makeRequest())
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testServerErrorMapsToTransient() async {
        respond(status: 500, json: "{}")

        do {
            _ = try await api.requestAdvice(makeRequest())
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .transient)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
