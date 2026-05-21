import AVFoundation
import AppKit
import Foundation

final class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()

    private let maxDimension: CGFloat = 320
    private let jpegQuality: CGFloat = 0.7

    private init() {}

    /// Generate JPEG thumbnail data from a photo file
    func generateThumbnailJPEG(from url: URL) -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return jpegData(from: image)
    }

    /// Generate JPEG thumbnail data from a video file (first frame)
    func generateVideoThumbnailJPEG(from url: URL) -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        let time = CMTime(value: 0, timescale: 1)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return jpegData(from: nsImage)
    }

    private func jpegData(from image: NSImage) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
    }

    private func resize(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let originalSize = image.size
        let widthRatio = maxDimension / originalSize.width
        let heightRatio = maxDimension / originalSize.height
        let ratio = min(widthRatio, heightRatio, 1.0)
        let newSize = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        return resized
    }
}
