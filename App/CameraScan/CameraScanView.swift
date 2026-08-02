import AVFoundation
import SwiftUI

struct CameraScanView: View {
    @EnvironmentObject private var flow: AppFlow
    @StateObject private var model = ScanViewModel()

    var body: some View {
        VStack(spacing: 18) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { preview }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.1))
                )
                .overlay {
                    ViewfinderCorners()
                        .stroke(model.capture == nil ? Theme.primary : .green,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .padding(18)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottom) { qualityBanner }
                .shadow(color: Theme.ink.opacity(0.12), radius: 16, y: 6)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Camera preview")

            if let capture = model.capture {
                capturedControls(capture)
            } else {
                Label("The scan is taken automatically as soon as the image is sharp and well lit.",
                      systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .padding(20)
        .themedScreen()
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
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(quality.isUsable ? Color.green.opacity(0.9) : Theme.ink.opacity(0.82),
                            in: Capsule())
                .padding(.bottom, 16)
                .accessibilityAddTraits(.updatesFrequently)
                .animation(.easeInOut(duration: 0.2), value: quality.guidance)
        }
    }

    private func capturedControls(_ capture: ScanCapture) -> some View {
        VStack(spacing: 14) {
            Label("Scan captured — sharpness \(Int(capture.quality.sharpness)), lighting OK",
                  systemImage: "checkmark.seal.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.green)

            HStack(spacing: 12) {
                Button("Retake") { model.retake() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Use this scan") {
                    flow.advanceToAdvice(with: capture)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

/// Four corner brackets that read instantly as "viewfinder".
struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.12
        var path = Path()
        for (x, y, dx, dy) in [
            (rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0),
            (rect.minX, rect.maxY, 1.0, -1.0), (rect.maxX, rect.maxY, -1.0, -1.0),
        ] {
            path.move(to: CGPoint(x: x + dx * arm, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + dy * arm))
        }
        return path
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
