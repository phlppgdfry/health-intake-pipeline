import Foundation

/// Persists advice requests that could not be sent (device offline) and
/// replays them once connectivity returns.
///
/// Design choices:
/// - Persisted to disk with complete file protection: a queued request
///   contains intake answers, which is health data.
/// - Deduplicated on `cacheKey`: re-submitting the same intake while offline
///   must not produce a burst of identical requests later.
/// - Replay is oldest-first and stops on the first failure, so order is
///   preserved and a flaky connection doesn't drain the queue into errors.
final class OfflineQueue {
    private(set) var pending: [AdviceRequest] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("offline-queue.json")
        pending = (try? Data(contentsOf: self.fileURL))
            .flatMap { try? JSONDecoder().decode([AdviceRequest].self, from: $0) } ?? []
    }

    func enqueue(_ request: AdviceRequest) {
        guard !pending.contains(where: { $0.cacheKey == request.cacheKey }) else { return }
        pending.append(request)
        persist()
    }

    /// Replays queued requests through `send`, removing each on success.
    /// Returns the responses that made it through on this attempt.
    func replay(using send: (AdviceRequest) async throws -> AdviceResponse) async
        -> [(AdviceRequest, AdviceResponse)] {
        var delivered: [(AdviceRequest, AdviceResponse)] = []
        while let next = pending.first {
            guard let response = try? await send(next) else { break }
            pending.removeFirst()
            delivered.append((next, response))
        }
        persist()
        return delivered
    }

    func removeAll() {
        pending = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
