@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage

/// Abstraction over the frame source so the scan flow runs identically on a
/// real device (AVFoundation) and in the simulator or tests (synthetic frames).
@MainActor
protocol FrameSource: AnyObject {
    /// Downscaled frames suitable for quality analysis, ~5 per second.
    var frames: AsyncStream<CGImage> { get }
    var captureSession: AVCaptureSession? { get }
    func start() async
    func stop()
}

/// Live camera capture. Owns the AVCaptureSession lifecycle: configuration and
/// start/stop happen off the main thread (Apple's requirement), frames are
/// delivered onto the analysis stream at a throttled rate.
@MainActor
final class LiveCameraService: NSObject, FrameSource {
    let captureSession: AVCaptureSession?
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let output = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()
    private var continuation: AsyncStream<CGImage>.Continuation?
    private var lastFrameTime = Date.distantPast

    private(set) lazy var frames = AsyncStream<CGImage> { continuation in
        self.continuation = continuation
    }

    override init() {
        captureSession = session
        super.init()
    }

    func start() async {
        guard await requestAccess() else { return }
        sessionQueue.async { [session, output] in
            guard session.inputs.isEmpty else {
                session.startRunning()
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .high
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frames"))
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            session.stopRunning()
        }
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}

extension LiveCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        Task { @MainActor in
            // Quality analysis needs ~5 fps, not 30/60 — drop the rest early.
            guard Date().timeIntervalSince(lastFrameTime) > 0.2 else { return }
            lastFrameTime = Date()
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
            continuation?.yield(cgImage)
        }
    }
}

/// Deterministic frame source for the simulator, previews and UI tests.
/// Emits blurred frames first, then sharp ones, so the full guidance →
/// auto-capture journey can be demonstrated without camera hardware.
@MainActor
final class SimulatedCameraService: FrameSource {
    let captureSession: AVCaptureSession? = nil
    private var continuation: AsyncStream<CGImage>.Continuation?
    private var task: Task<Void, Never>?

    private(set) lazy var frames = AsyncStream<CGImage> { continuation in
        self.continuation = continuation
    }

    func start() async {
        task = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                let sharp = tick >= 10 // ~2 seconds of "blurry", then sharp
                if let frame = SyntheticFrame.make(sharp: sharp) {
                    self?.continuation?.yield(frame)
                }
                tick += 1
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func stop() {
        task?.cancel()
    }
}

/// Generates test-card images: a high-contrast checkerboard (sharp) or a flat
/// gradient (no edges, reads as blurred). Shared by the simulator source and
/// the unit tests so both exercise the same analyzer behavior.
enum SyntheticFrame {
    static func make(sharp: Bool, size: Int = 256) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                if sharp {
                    let block = 16
                    let on = ((x / block) + (y / block)) % 2 == 0
                    pixels[y * size + x] = on ? 235 : 25
                } else {
                    pixels[y * size + x] = UInt8(80 + (x * 60) / size)
                }
            }
        }
        return pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            let context = CGContext(
                data: buffer.baseAddress,
                width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
            return context?.makeImage()
        }
    }
}
