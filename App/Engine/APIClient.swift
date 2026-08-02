import Foundation

struct AdviceRequest: Codable, Equatable {
    let answers: [IntakeAnswer]
    let scanSharpness: Double

    /// Stable key for caching and deduplication in the offline queue.
    var cacheKey: String {
        answers.map { "\($0.questionID)=\($0.answer)" }.sorted().joined(separator: "&")
    }
}

struct AdviceResponse: Codable, Equatable {
    /// `nil` until the backend has clinically approved the submission — the
    /// server withholds content, it isn't just hidden client-side.
    let summary: String?
    let recommendations: [String]?
    /// Advice may only be shown to the user once this is true — see SignOffGate.
    let clinicallyApproved: Bool
    /// The backend submission id, used to poll for a later approval. `nil`
    /// for `MockAdviceAPI`, which never needs polling.
    var submissionID: String? = nil
}

enum APIError: Error, Equatable {
    case offline
    case transient
}

protocol AdviceAPI: Sendable {
    func requestAdvice(_ request: AdviceRequest) async throws -> AdviceResponse
    /// Re-fetches a previously submitted request's current status. Only
    /// meaningful once review is server-side and asynchronous — see
    /// `RemoteAdviceAPI`.
    func pollForApproval(submissionID: String) async throws -> AdviceResponse
}

/// Retry wrapper around any AdviceAPI: transient failures are retried with
/// exponential backoff; `offline` is *not* retried here — that is the offline
/// queue's job, because blind retries against a dead connection waste battery.
struct RetryingAdviceAPI: AdviceAPI {
    let wrapped: AdviceAPI
    var maxAttempts = 3
    var baseDelay: Duration = .milliseconds(300)

    func requestAdvice(_ request: AdviceRequest) async throws -> AdviceResponse {
        var attempt = 0
        while true {
            do {
                return try await wrapped.requestAdvice(request)
            } catch APIError.transient {
                attempt += 1
                guard attempt < maxAttempts else { throw APIError.transient }
                try await Task.sleep(for: baseDelay * (1 << attempt))
            }
        }
    }

    /// No backoff here — the caller's poll loop already provides the retry
    /// cadence; wrapping it again would just double up the delay.
    func pollForApproval(submissionID: String) async throws -> AdviceResponse {
        try await wrapped.pollForApproval(submissionID: submissionID)
    }
}

/// Stands in for the real advice engine. Simulates latency and returns a
/// deterministic response; failure behavior is injectable for tests.
final class MockAdviceAPI: AdviceAPI {
    let failure: APIError?

    init(failure: APIError? = nil) {
        self.failure = failure
    }

    func requestAdvice(_ request: AdviceRequest) async throws -> AdviceResponse {
        try await Task.sleep(for: .milliseconds(600))
        if let failure { throw failure }
        return AdviceResponse(
            summary: "Based on your \(request.answers.count) answers and a scan with sharpness \(Int(request.scanSharpness)), here is your personal advice.",
            recommendations: [
                "Keep a short daily log of your symptoms for two weeks.",
                "Discuss the scan result during your next consultation.",
                "Re-scan in the app if the concern changes visibly.",
            ],
            clinicallyApproved: true
        )
    }

    /// Never actually reached in practice: `requestAdvice` already returns
    /// an approved response, so `AdviceView` never enters the withheld/poll
    /// branch with a mock backend. Kept for protocol conformance and tests.
    func pollForApproval(submissionID: String) async throws -> AdviceResponse {
        try await requestAdvice(AdviceRequest(answers: [], scanSharpness: 0))
    }
}
