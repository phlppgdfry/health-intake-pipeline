import CoreGraphics
import Foundation

/// Scores a frame *before* capture so the vision pipeline downstream only ever
/// receives usable input. Pure function of a CGImage — no camera dependency —
/// so it is trivially unit-testable with synthetic images.
///
/// Sharpness uses the variance-of-Laplacian measure: convolve the grayscale
/// image with a Laplacian kernel and measure the variance of the response.
/// Blur suppresses edges, which collapses that variance.
struct FrameQualityAnalyzer {
    /// Frames are downscaled before analysis: quality metrics are stable at low
    /// resolution and this keeps per-frame cost well under a frame interval.
    private static let analysisWidth = 128

    func analyze(_ image: CGImage) -> CaptureQuality {
        let gray = grayscalePixels(of: image, width: Self.analysisWidth)
        return CaptureQuality(
            sharpness: laplacianVariance(gray.pixels, width: gray.width, height: gray.height),
            brightness: gray.pixels.reduce(0.0) { $0 + Double($1) } / Double(gray.pixels.count) / 255.0
        )
    }

    // MARK: - Internals

    private func grayscalePixels(of image: CGImage, width targetWidth: Int)
        -> (pixels: [UInt8], width: Int, height: Int) {
        let scale = Double(targetWidth) / Double(image.width)
        let width = targetWidth
        let height = max(1, Int(Double(image.height) * scale))

        var pixels = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return (pixels, width, height)
    }

    private func laplacianVariance(_ pixels: [UInt8], width: Int, height: Int) -> Double {
        guard width > 2, height > 2 else { return 0 }
        var responses = [Double]()
        responses.reserveCapacity((width - 2) * (height - 2))

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Double(pixels[y * width + x])
                let neighbors = Double(pixels[(y - 1) * width + x])
                    + Double(pixels[(y + 1) * width + x])
                    + Double(pixels[y * width + x - 1])
                    + Double(pixels[y * width + x + 1])
                responses.append(4 * center - neighbors)
            }
        }

        let mean = responses.reduce(0, +) / Double(responses.count)
        return responses.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(responses.count)
    }
}
