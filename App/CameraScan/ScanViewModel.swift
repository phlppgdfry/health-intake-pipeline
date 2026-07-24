import CoreGraphics
import Foundation

/// The captured scan plus the quality evidence it was accepted with. The
/// quality report travels with the image so the downstream pipeline can trust
/// — and audit — what it received.
struct ScanCapture {
    let image: CGImage
    let quality: CaptureQuality
    let capturedAt: Date
}

/// Watches the live quality stream and auto-captures once quality has been
/// good for several consecutive frames — one good frame can be luck; a stable
/// window means the user is actually holding a usable shot.
@MainActor
final class ScanViewModel: ObservableObject {
    @Published private(set) var latestFrame: CGImage?
    @Published private(set) var quality: CaptureQuality?
    @Published private(set) var capture: ScanCapture?

    /// Consecutive usable frames required before auto-capture.
    static let requiredStableFrames = 3

    let source: FrameSource
    private let analyzer = FrameQualityAnalyzer()
    private let framingChecker = FaceFramingChecker()
    private var stableCount = 0
    private var streamTask: Task<Void, Never>?

    init(source: FrameSource? = nil) {
        #if targetEnvironment(simulator)
        self.source = source ?? SimulatedCameraService()
        #else
        self.source = source ?? LiveCameraService()
        #endif
    }

    func start() async {
        await source.start()
        streamTask = Task { [weak self] in
            guard let frames = self?.source.frames else { return }
            for await frame in frames {
                self?.process(frame)
                if self?.capture != nil { break }
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        source.stop()
    }

    func retake() {
        capture = nil
        stableCount = 0
        Task { await start() }
    }

    private func process(_ frame: CGImage) {
        latestFrame = frame
        var report = analyzer.analyze(frame)
        if source.requiresSubjectFraming {
            report.framing = framingChecker.check(frame)
        }
        quality = report

        if report.isUsable {
            stableCount += 1
            if stableCount >= Self.requiredStableFrames {
                capture = ScanCapture(image: frame, quality: report, capturedAt: Date())
                Log.scan.info("Auto-capture: sharpness \(Int(report.sharpness), privacy: .public), brightness \(report.brightness, format: .fixed(precision: 2), privacy: .public)")
                CaptureFeedback.play()
                stop()
            }
        } else {
            stableCount = 0
        }
    }
}
