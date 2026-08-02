import Foundation

/// Persists in-progress intake answers so a killed or backgrounded app can
/// resume the questionnaire instead of starting over. Deliberately doesn't
/// persist the camera capture — `ScanCapture` holds a raw `CGImage`, and
/// re-scanning is the expected, cheap recovery path if the app dies on the
/// scan screen; the drafted answers save the user from re-answering.
///
/// Same storage pattern as `OfflineQueue`/`AdviceCache`: Application Support
/// (survives OS cache purges) with complete file protection (health data).
final class IntakeDraftStore {
    struct Draft: Codable, Equatable {
        let answers: [IntakeAnswer]
        let step: AppFlow.Step
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("intake-draft.json")
    }

    var draft: Draft? {
        (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode(Draft.self, from: $0) }
    }

    func save(answers: [IntakeAnswer], step: AppFlow.Step) {
        guard let data = try? JSONEncoder().encode(Draft(answers: answers, step: step)) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
