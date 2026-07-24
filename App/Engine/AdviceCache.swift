import Foundation

/// File-backed cache for advice responses.
///
/// Two properties matter for health data:
/// - Files are written with `.completeFileProtection`, so they are encrypted
///   at rest whenever the device is locked.
/// - The cache lives in Application Support (not Caches), because a served
///   advice must survive OS cache purges until the user or consent removes it.
final class AdviceCache {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AdviceCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func store(_ response: AdviceResponse, for request: AdviceRequest) {
        guard let data = try? encoder.encode(response) else { return }
        try? data.write(to: fileURL(for: request.cacheKey),
                        options: [.atomic, .completeFileProtection])
    }

    func response(for request: AdviceRequest) -> AdviceResponse? {
        guard let data = try? Data(contentsOf: fileURL(for: request.cacheKey)) else { return nil }
        return try? decoder.decode(AdviceResponse.self, from: data)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for key: String) -> URL {
        // Keys contain user text; hash them so file names stay valid and opaque.
        directory.appendingPathComponent("\(key.hashValue.magnitude).json")
    }
}
