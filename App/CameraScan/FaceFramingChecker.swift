import CoreGraphics
import Vision

/// Third capture gate, after sharpness and exposure: is the subject actually
/// in frame? Uses Vision's face detector and turns the raw bounding box into
/// the same kind of actionable verdict the other checks produce.
///
/// Thresholds are normalized to the frame, so they hold across resolutions:
/// the face must cover at least 5% of the frame (close enough for detail) and
/// its center must sit in the middle band (not clipped at an edge).
struct FaceFramingChecker {
    static let minFaceArea = 0.05
    static let centerBand = 0.2...0.8

    func check(_ image: CGImage) -> CaptureQuality.Framing {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try? handler.perform([request])

        guard let face = request.results?
            .max(by: { area($0.boundingBox) < area($1.boundingBox) }) else {
            return .noSubject
        }
        let box = face.boundingBox // normalized, origin bottom-left
        guard area(box) >= Self.minFaceArea else { return .tooFar }
        guard Self.centerBand.contains(box.midX),
              Self.centerBand.contains(box.midY) else { return .offCenter }
        return .ok
    }

    private func area(_ box: CGRect) -> Double {
        box.width * box.height
    }
}
