import Foundation
import AVFoundation
import CoreImage
import AppKit

final class MotionDetector: ObservableObject {
    static let shared = MotionDetector()

    @Published var isMotionDetected = false

    private var previousPixelSum: UInt64 = 0
    private var previousPixelCount: Int = 0
    private var lastDetectionTime: Date = .distantPast
    private let analysisSize = CGSize(width: 64, height: 48)  // low-res for speed

    var onMotionDetected: (() -> Void)?

    private init() {}

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard SettingsStore.shared.enableMotionDetection else { return }

        let now = Date()
        let cooldown = TimeInterval(SettingsStore.shared.motionCooldownSeconds)
        guard now.timeIntervalSince(lastDetectionTime) >= cooldown else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        // Downscale for fast comparison
        let scaleX = analysisSize.width / ciImage.extent.width
        let scaleY = analysisSize.height / ciImage.extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Convert to grayscale for simpler comparison
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return }
        grayscaleFilter.setValue(scaled, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let grayscale = grayscaleFilter.outputImage else { return }

        // Render to bitmap
        let context = CIContext()
        let rect = CGRect(origin: .zero, size: analysisSize)
        guard let cgImage = context.createCGImage(grayscale, from: rect) else { return }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * Int(analysisSize.width)
        var pixelData = [UInt8](repeating: 0, count: Int(analysisSize.width * analysisSize.height) * bytesPerPixel)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        guard let bitmapContext = CGContext(
            data: &pixelData,
            width: Int(analysisSize.width),
            height: Int(analysisSize.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        bitmapContext.draw(cgImage, in: rect)

        // Sum pixel values for simple diff
        var currentSum: UInt64 = 0
        let pixelCount = Int(analysisSize.width * analysisSize.height)
        for i in 0..<(pixelCount * bytesPerPixel) {
            currentSum += UInt64(pixelData[i])
        }

        // Compare with previous frame
        if previousPixelCount > 0 {
            let diff = currentSum > previousPixelSum ? currentSum - previousPixelSum : previousPixelSum - currentSum
            let avgDiffPerPixel = Double(diff) / Double(pixelCount)

            // Sensitivity thresholds: low=~30, medium=~15, high=~8
            let sensitivity = SettingsStore.shared.motionSensitivity
            let threshold: Double
            switch sensitivity {
            case 1: threshold = 30.0
            case 3: threshold = 8.0
            default: threshold = 15.0
            }

            if avgDiffPerPixel > threshold {
                lastDetectionTime = now
                DispatchQueue.main.async { [weak self] in
                    self?.isMotionDetected = true
                    self?.onMotionDetected?()
                    // Reset indicator after cooldown
                    DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) {
                        self?.isMotionDetected = false
                    }
                }
                ActivityLogManager.shared.info(.motion, Strings.motionDetected, detail: "Diff: \(String(format: "%.1f", avgDiffPerPixel))")
            }
        }

        previousPixelSum = currentSum
        previousPixelCount = pixelCount
    }
}
