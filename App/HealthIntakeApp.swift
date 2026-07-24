import SwiftUI

@main
struct HealthIntakeApp: App {
    @StateObject private var flow = AppFlow()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(flow)
        }
    }
}

/// The single source of truth for where the user is in the intake journey.
/// Consent always comes first; the camera is unreachable without it.
@MainActor
final class AppFlow: ObservableObject {
    enum Step: Equatable {
        case consent
        case intake
        case scan
        case advice
    }

    @Published var step: Step
    @Published var intakeAnswers: [IntakeAnswer] = []
    @Published var capture: ScanCapture?

    let consentStore: ConsentStore
    let engine: AdviceEngine

    init(consentStore: ConsentStore = ConsentStore(),
         engine: AdviceEngine? = nil) {
        // UI tests need a deterministic starting point.
        if ProcessInfo.processInfo.arguments.contains("--reset-state") {
            consentStore.revoke()
        }
        self.consentStore = consentStore
        self.engine = engine ?? AdviceEngine(
            api: MockAdviceAPI(),
            cache: AdviceCache(),
            queue: OfflineQueue()
        )
        step = consentStore.hasConsent ? .intake : .consent
    }

    func revokeConsent() {
        consentStore.revoke()
        intakeAnswers = []
        capture = nil
        step = .consent
    }
}
