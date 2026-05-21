import Foundation
import AVFoundation
import AppKit

final class TimelapseManager: ObservableObject {
    static let shared = TimelapseManager()

    @Published private(set) var isCapturing = false
    @Published private(set) var frameCount = 0

    private var captureTimer: Timer?
    private var capturedFrames: [URL] = []

    private init() {}

    func start() {
        guard SettingsStore.shared.timelapseEnabled else { return }
        guard !isCapturing else { return }

        isCapturing = true
        frameCount = 0
        capturedFrames = []

        let interval = TimeInterval(SettingsStore.shared.timelapseIntervalSeconds)
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
        captureFrame() // First frame immediately
        ActivityLogManager.shared.info(.timelapse, "Timelapse started (interval: \(Int(interval))s)")
    }

    func stop() {
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false

        if !capturedFrames.isEmpty {
            compileVideo()
        }
    }

    private func captureFrame() {
        let camera = CameraManager.shared
        camera.ensureSessionRunning { [weak self] in
            camera.capturePhoto { result in
                switch result {
                case .success(let url):
                    self?.capturedFrames.append(url)
                    self?.frameCount += 1
                case .failure(let error):
                    ActivityLogManager.shared.error(.timelapse, "Frame capture failed", detail: error.localizedDescription)
                }
            }
        }
    }

    private func compileVideo() {
        let fps = SettingsStore.shared.timelapseFPS
        guard fps > 0, !capturedFrames.isEmpty else { return }

        let outputURL = MediaLibraryManager.shared.videosDirectory.appendingPathComponent("Timelapse_\(timestampString()).mp4")

        Task {
            do {
                try await compileFramesToVideo(frames: capturedFrames, outputURL: outputURL, fps: fps)
                let fileName = outputURL.lastPathComponent
                MediaIndexStore.shared.setSource(.manual, for: fileName)
                ActivityLogManager.shared.success(.timelapse, "Timelapse compiled: \(fileName) (\(frameCount) frames)")

                if SettingsStore.shared.autoUploadTimelapse {
                    UploadQueueManager.shared.enqueue(fileName: fileName)
                }
            } catch {
                ActivityLogManager.shared.error(.timelapse, "Timelapse compilation failed", detail: error.localizedDescription)
            }
        }
    }

    private func compileFramesToVideo(frames: [URL], outputURL: URL, fps: Int) async throws {
        guard let firstFrame = frames.first,
              let image = NSImage(contentsOf: firstFrame),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "Timelapse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read first frame"])
        }

        let width = cgImage.width
        let height = cgImage.height

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        let frameDurationSeconds = 1.0 / Double(fps)

        for (index, frameURL) in frames.enumerated() {
            guard let img = NSImage(contentsOf: frameURL),
                  let cgImg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

            let time = CMTime(seconds: Double(index) * frameDurationSeconds, preferredTimescale: 600)

            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            if let pixelBuffer = createPixelBuffer(from: cgImg, width: width, height: height) {
                adaptor.append(pixelBuffer, withPresentationTime: time)
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
    }

    private func createPixelBuffer(from cgImage: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)

        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
