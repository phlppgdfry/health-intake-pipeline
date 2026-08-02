import Foundation
import Network

/// Coordinates API, cache and offline queue into one policy:
///
/// 1. Cache hit → serve immediately (an advice, once given, stays available).
/// 2. Online → request with retry, cache the result.
/// 3. Offline → enqueue for later and tell the UI honestly that the request
///    is queued, instead of spinning forever.
final class AdviceEngine {
    enum Outcome: Equatable {
        case advice(AdviceResponse)
        case queuedOffline
    }

    private let api: AdviceAPI
    private let cache: AdviceCache
    private let queue: OfflineQueue
    private let isOnline: () -> Bool

    init(api: AdviceAPI,
         cache: AdviceCache,
         queue: OfflineQueue,
         isOnline: @escaping () -> Bool = ConnectivityMonitor.shared.isOnline) {
        self.api = RetryingAdviceAPI(wrapped: api)
        self.cache = cache
        self.queue = queue
        self.isOnline = isOnline
    }

    func advice(for request: AdviceRequest) async -> Outcome {
        if let cached = cache.response(for: request) {
            Log.engine.info("Advice served from cache")
            return .advice(cached)
        }
        guard isOnline() else {
            queue.enqueue(request)
            Log.engine.info("Offline — request queued (\(self.queue.pending.count, privacy: .public) pending)")
            return .queuedOffline
        }
        do {
            let response = try await api.requestAdvice(request)
            // Only cache once approved — an unapproved response would
            // otherwise short-circuit every future load and poll straight
            // from a stale cache entry that can never become "released".
            if response.clinicallyApproved {
                cache.store(response, for: request)
            }
            Log.engine.info("Advice fetched and cached")
            return .advice(response)
        } catch {
            queue.enqueue(request)
            Log.engine.error("Request failed after retries — queued: \(error, privacy: .public)")
            return .queuedOffline
        }
    }

    /// Re-checks a submission that was withheld pending clinical review.
    /// Returns `nil` on transient failure — the caller (`AdviceView`'s poll
    /// loop) simply tries again on the next tick.
    func pollForApproval(submissionID: String, request: AdviceRequest) async -> AdviceResponse? {
        guard let response = try? await api.pollForApproval(submissionID: submissionID) else {
            return nil
        }
        if response.clinicallyApproved {
            cache.store(response, for: request)
        }
        return response
    }

    /// Called when connectivity returns; delivered *approved* responses land
    /// in the cache so the next lookup succeeds instantly. A withheld
    /// response isn't cached, for the same reason as in `advice(for:)`.
    func flushOfflineQueue() async {
        let delivered = await queue.replay(using: api.requestAdvice)
        for (request, response) in delivered where response.clinicallyApproved {
            cache.store(response, for: request)
        }
    }
}

/// Thin NWPathMonitor wrapper. Kept out of AdviceEngine so tests can inject
/// connectivity as a plain closure.
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()
    private let monitor = NWPathMonitor()
    private var online = true

    /// Fires when the path flips from unsatisfied to satisfied — fase 3's
    /// hook for automatically flushing the offline queue on reconnect
    /// (wired in `AppFlow.init`), instead of only retrying on the next
    /// manual advice request.
    var onConnectivityRestored: (() -> Void)?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasOffline = !self.online
            self.online = path.status == .satisfied
            if wasOffline && self.online {
                self.onConnectivityRestored?()
            }
        }
        monitor.start(queue: DispatchQueue(label: "connectivity"))
    }

    func isOnline() -> Bool { online }
}
