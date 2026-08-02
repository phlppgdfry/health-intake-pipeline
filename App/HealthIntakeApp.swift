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
    enum Step: Equatable, Codable {
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
    private let draftStore: IntakeDraftStore

    init(consentStore: ConsentStore = ConsentStore(),
         engine: AdviceEngine? = nil,
         draftStore: IntakeDraftStore = IntakeDraftStore()) {
        // UI tests need a deterministic starting point.
        if ProcessInfo.processInfo.arguments.contains("--reset-state") {
            consentStore.revoke()
            draftStore.clear()
        }
        self.consentStore = consentStore
        self.engine = engine ?? AppFlow.makeDefaultEngine()
        self.draftStore = draftStore

        // Fase 3: resume an interrupted intake instead of always restarting
        // at question one. Only meaningful with consent already given —
        // without it we land on `.consent` regardless. The camera capture
        // itself is never persisted (see `IntakeDraftStore`), so a drafted
        // `.scan` step just means "answers are ready, redo the scan".
        if consentStore.hasConsent, let draft = draftStore.draft {
            intakeAnswers = draft.answers
            step = draft.step
        } else {
            step = consentStore.hasConsent ? .intake : .consent
        }

        // Fase 3: don't wait for the next manual advice request to notice
        // connectivity came back — flush the offline queue immediately.
        let flushEngine = self.engine
        ConnectivityMonitor.shared.onConnectivityRestored = {
            Task { await flushEngine.flushOfflineQueue() }
        }
    }

    /// `MockAdviceAPI` is the default so CI and `UITests` never need a
    /// running backend. Set `API_BASE_URL` (see the `HealthIntake` scheme's
    /// environment variables, disabled by default) to demo against the real
    /// backend from `Backend/HealthIntake.Api`.
    private static func makeDefaultEngine() -> AdviceEngine {
        let api: AdviceAPI
        if let baseURLString = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let baseURL = URL(string: baseURLString) {
            api = RemoteAdviceAPI(baseURL: baseURL)
        } else {
            api = MockAdviceAPI()
        }
        return AdviceEngine(api: api, cache: AdviceCache(), queue: OfflineQueue())
    }

    func revokeConsent() {
        consentStore.revoke()
        intakeAnswers = []
        capture = nil
        step = .consent
        draftStore.clear()
    }

    /// Called on every answer, not just at completion, so a kill mid-way
    /// through the questionnaire loses at most the current tap.
    func recordIntakeAnswers(_ answers: [IntakeAnswer]) {
        intakeAnswers = answers
        draftStore.save(answers: answers, step: .intake)
    }

    func advanceToScan() {
        step = .scan
        draftStore.save(answers: intakeAnswers, step: .scan)
    }

    /// Once a capture exists the draft's job is done — advice has been
    /// requested, so there's nothing left to resume.
    func advanceToAdvice(with capture: ScanCapture) {
        self.capture = capture
        step = .advice
        draftStore.clear()
    }
}
