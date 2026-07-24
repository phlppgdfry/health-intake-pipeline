import AVFoundation
import SwiftUI

struct CameraScanView: View {
    @EnvironmentObject private var flow: AppFlow
    @StateObject private var model = ScanViewModel()

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                preview
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .bottom) { qualityBanner }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Camera preview")

            if let capture = model.capture {
                capturedControls(capture)
            } else {
                Text("The scan is taken automatically as soon as the image is sharp and well lit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var preview: some View {
        if let capture = model.capture {
            Image(decorative: capture.image, scale: 1)
                .resizable()
                .scaledToFill()
        } else if let session = model.source.captureSession {
            CameraPreviewView(session: session)
        } else if let frame = model.latestFrame {
            // Simulator fallback: show the synthetic frames being analyzed.
            Image(decorative: frame, scale: 1)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle().fill(.black)
        }
    }

    @ViewBuilder
    private var qualityBanner: some View {
        if model.capture == nil, let quality = model.quality {
            Label(quality.guidance ?? "Hold it right there…",
                  systemImage: quality.isUsable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 12)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func capturedControls(_ capture: ScanCapture) -> some View {
        VStack(spacing: 12) {
            Label("Scan captured — sharpness \(Int(capture.quality.sharpness)), lighting OK",
                  systemImage: "checkmark.seal.fill")
                .font(.callout)
                .foregroundStyle(.green)

            HStack {
                Button("Retake") { model.retake() }
                    .buttonStyle(.bordered)
                Button("Use this scan") {
                    flow.capture = capture
                    flow.step = .advice
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
    }
}

/// Thin UIKit bridge for the AVFoundation preview layer.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
