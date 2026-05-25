import AVFoundation
import Foundation
import ImageIO

final class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()

    private let maxDimension: CGFloat = 320
    private let jpegQuality: CGFloat = 0.7

    private init() {}

    /// Generate JPEG thumbnail data from a photo file
    func generateThumbnailJPEG(from url: URL) -> Data? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        return jpegData(from: cgImage)
    }

    /// Generate JPEG thumbnail data from a video file (first frame)
    func generateVideoThumbnailJPEG(from url: URL) -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        let time = CMTime(value: 0, timescale: 1)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
        return jpegData(from: cgImage)
    }

    private func jpegData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return data as Data
    }
}

