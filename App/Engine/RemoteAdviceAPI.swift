import CryptoKit
import Foundation

/// Talks to the fase-1 backend (`Backend/HealthIntake.Api`). Opt-in via
/// `API_BASE_URL` in `HealthIntakeApp` — `MockAdviceAPI` stays the default
/// so CI and `UITests` never need a running backend.
struct RemoteAdviceAPI: AdviceAPI {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func requestAdvice(_ request: AdviceRequest) async throws -> AdviceResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/intake-submissions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Same intake content → same idempotency key → the server returns
        // the existing submission instead of creating a duplicate on a
        // retry or offline-queue replay (fase 3).
        urlRequest.setValue(Self.idempotencyKey(for: request), forHTTPHeaderField: "Idempotency-Key")
        // ASP.NET Core's default JSON model binding is case-insensitive, so
        // `AdviceRequest`'s existing `questionID`/`scanSharpness` keys map
        // straight onto the server's `QuestionId`/`ScanSharpness` — no
        // separate wire DTO needed.
        urlRequest.httpBody = try JSONEncoder().encode(request)
        return try await send(urlRequest)
    }

    private static func idempotencyKey(for request: AdviceRequest) -> String {
        let digest = SHA256.hash(data: Data(request.cacheKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func pollForApproval(submissionID: String) async throws -> AdviceResponse {
        let url = baseURL.appendingPathComponent("api/intake-submissions/\(submissionID)")
        return try await send(URLRequest(url: url))
    }

    /// Only the fields the app actually renders — `createdAt`/`reviewedAt`
    /// are left out on purpose to sidestep .NET's fractional-seconds date
    /// format, which `JSONDecoder`'s ISO-8601 strategy doesn't reliably parse.
    private struct RemoteSubmission: Decodable {
        let id: String
        let summary: String?
        let recommendations: [String]?
        let clinicallyApproved: Bool
    }

    private func send(_ urlRequest: URLRequest) async throws -> AdviceResponse {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .timedOut:
                throw APIError.offline
            default:
                throw APIError.transient
            }
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.transient
        }

        guard let decoded = try? JSONDecoder().decode(RemoteSubmission.self, from: data) else {
            throw APIError.transient
        }

        return AdviceResponse(
            summary: decoded.summary,
            recommendations: decoded.recommendations,
            clinicallyApproved: decoded.clinicallyApproved,
            submissionID: decoded.id
        )
    }
}
