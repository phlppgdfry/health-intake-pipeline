import Foundation

/// The quality verdict for a single camera frame.
///
/// The thresholds are intentionally explicit constants rather than magic
/// numbers inside the analyzer: they are the contract between the capture UI
/// ("hold still, too dark…") and the vision pipeline downstream, and they are
/// exercised directly by unit tests.
struct CaptureQuality: Equatable {
    /// Subject framing, from the Vision face check. `.notRequired` covers
    /// frame sources without a framing contract (synthetic test cards).
    enum Framing: Equatable {
        case notRequired
        case ok
        case noSubject
        case tooFar
        case offCenter
    }

    /// Variance of the Laplacian on the grayscale frame. Low variance means
    /// few edges survived — the classic signal for a blurred image.
    let sharpness: Double
    /// Mean luminance in 0...1.
    let brightness: Double
    var framing: Framing = .notRequired

    static let minSharpness = 60.0
    static let brightnessRange = 0.18...0.85

    var isSharp: Bool { sharpness >= Self.minSharpness }
    var isWellLit: Bool { Self.brightnessRange.contains(brightness) }
    var isFramed: Bool { framing == .ok || framing == .notRequired }
    var isUsable: Bool { isSharp && isWellLit && isFramed }

    /// One actionable instruction for the user, worst problem first: fix
    /// motion before framing, framing before lighting.
    var guidance: String? {
        if !isSharp { return "Hold the phone still" }
        switch framing {
        case .noSubject: return "Position your face in the frame"
        case .tooFar: return "Move a little closer"
        case .offCenter: return "Center your face"
        case .ok, .notRequired: break
        }
        if brightness < Self.brightnessRange.lowerBound { return "Find more light" }
        if brightness > Self.brightnessRange.upperBound { return "Too bright — avoid direct light" }
        return nil
    }
}
