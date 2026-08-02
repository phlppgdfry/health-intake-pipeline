import Foundation

/// A queued request plus how many delivery attempts it has had.
struct QueuedRequest: Codable, Equatable {
    let request: AdviceRequest
    var attempts: Int = 0
}

/// Persists advice requests that could not be sent (device offline) and
/// replays them once connectivity returns.
///
/// Design choices:
/// - Persisted to disk with complete file protection: a queued request
///   contains intake answers, which is health data.
/// - Deduplicated on `cacheKey`: re-submitting the same intake while offline
///   must not produce a burst of identical requests later.
/// - Every item gets a shot on each replay (fase 3): one chronically failing
///   item no longer blocks the rest of the queue behind it. An item that
///   keeps failing past `maxAttempts` is dropped rather than retried forever
///   — every request the app sends is well-formed by construction, so a
///   repeated failure here means "server unreachable", not "invalid data",
///   and `RemoteAdviceAPI`'s idempotency key means a drop is safe: replaying
///   it later (e.g. a fresh enqueue) can't create a duplicate submission.
final class OfflineQueue {
    private(set) var pending: [QueuedRequest] = []
    private let fileURL: URL
    private let maxAttempts: Int

    init(fileURL: URL? = nil, maxAttempts: Int = 5) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("offline-queue.json")
        self.maxAttempts = maxAttempts
        pending = (try? Data(contentsOf: self.fileURL))
            .flatMap { try? JSONDecoder().decode([QueuedRequest].self, from: $0) } ?? []
    }

    func enqueue(_ request: AdviceRequest) {
        guard !pending.contains(where: { $0.request.cacheKey == request.cacheKey }) else { return }
        pending.append(QueuedRequest(request: request))
        persist()
    }

    /// Tries every queued item once, oldest first. Items that fail are kept
    /// (with an incremented attempt count) unless they've exhausted
    /// `maxAttempts`, in which case they're dropped. Returns the responses
    /// that made it through on this pass.
    func replay(using send: (AdviceRequest) async throws -> AdviceResponse) async
        -> [(AdviceRequest, AdviceResponse)] {
        var delivered: [(AdviceRequest, AdviceResponse)] = []
        var remaining: [QueuedRequest] = []

        for item in pending {
            guard let response = try? await send(item.request) else {
                var retried = item
                retried.attempts += 1
                if retried.attempts < maxAttempts {
                    remaining.append(retried)
                }
                continue
            }
            delivered.append((item.request, response))
        }

        pending = remaining
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
