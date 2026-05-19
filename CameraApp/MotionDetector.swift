import Foundation
import AVFoundation
import CoreImage
import AppKit

final class MotionDetector: ObservableObject {
    static let shared = MotionDetector()

    @Published var isMotionDetected = false

    private let analysisSize = CGSize(width: 80, height: 60)
    private let gridCols = 8
    private let gridRows = 6
    private var previousBlockBrightness: [Float] = []
    private var lastAnalysisTime: Date = .distantPast
    private let analysisInterval: TimeInterval = 1.0
    private var lastDetectionTime: Date = .distantPast

    var onMotionDetected: (() -> Void)?

    private init() {}

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard SettingsStore.shared.enableMotionDetection else { return }

        let now = Date()
        let cooldown = TimeInterval(SettingsStore.shared.motionCooldownSeconds)

        // Respect analysis interval — only analyze once per second
        guard now.timeIntervalSince(lastAnalysisTime) >= analysisInterval else { return }
        lastAnalysisTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        let scaleX = analysisSize.width / ciImage.extent.width
        let scaleY = analysisSize.height / ciImage.extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return }
        grayscaleFilter.setValue(scaled, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let grayscale = grayscaleFilter.outputImage else { return }

        let context = CIContext()
        let rect = CGRect(origin: .zero, size: analysisSize)
        guard let cgImage = context.createCGImage(grayscale, from: rect) else { return }

        let width = Int(analysisSize.width)
        let height = Int(analysisSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        guard let bitmapContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        bitmapContext.draw(cgImage, in: rect)

        // Calculate block-based brightness
        let blockW = width / gridCols
        let blockH = height / gridRows
        var currentBlocks = [Float](repeating: 0, count: gridCols * gridRows)

        for row in 0..<gridRows {
            for col in 0..<gridCols {
                var sum: Float = 0
                var count = 0
                let startX = col * blockW
                let startY = row * blockH
                for y in startY..<(startY + blockH) {
                    for x in startX..<(startX + blockW) {
                        let offset = (y * width + x) * bytesPerPixel
                        sum += Float(pixelData[offset])
                        count += 1
                    }
                }
                currentBlocks[row * gridCols + col] = sum / Float(count)
            }
        }

        // Compare with previous frame
        guard previousBlockBrightness.count == currentBlocks.count else {
            previousBlockBrightness = currentBlocks
            return
        }

        let sensitivity = SettingsStore.shared.motionSensitivity
        let blockDiffThreshold: Float
        let changedBlockCountThreshold: Int
        switch sensitivity {
        case 1:  // low
            blockDiffThreshold = 25
            changedBlockCountThreshold = 8
        case 3:  // high
            blockDiffThreshold = 12
            changedBlockCountThreshold = 3
        default: // medium
            blockDiffThreshold = 18
            changedBlockCountThreshold = 5
        }

        var changedBlocks = 0
        for i in 0..<currentBlocks.count {
            let diff = abs(currentBlocks[i] - previousBlockBrightness[i])
            if diff > blockDiffThreshold {
                changedBlocks += 1
            }
        }

        previousBlockBrightness = currentBlocks

        // Respect cooldown after detection — baseline is already updated above
        guard now.timeIntervalSince(lastDetectionTime) >= cooldown else { return }

        if changedBlocks >= changedBlockCountThreshold {
            lastDetectionTime = now
            DispatchQueue.main.async { [weak self] in
                self?.isMotionDetected = true
                self?.onMotionDetected?()
                DispatchQueue.main.asyncAfter(deadline: .now() + cooldown) {
                    self?.isMotionDetected = false
                }
            }
            ActivityLogManager.shared.log(
                level: .info,
                category: .motion,
                message: Strings.motionDetected,
                detail: "Changed blocks: \(changedBlocks)/\(gridCols * gridRows), threshold: \(blockDiffThreshold), sensitivity: \(sensitivity)"
            )
        }
    }
}
