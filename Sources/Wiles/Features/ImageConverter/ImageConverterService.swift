import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

public enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg
    case png
    case heic
    case tiff

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jpeg: return "JPEG (.jpg)"
        case .png: return "PNG (.png)"
        case .heic: return "HEIC (.heic)"
        case .tiff: return "TIFF (.tiff)"
        }
    }

    public var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .tiff: return .tiff
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }
}

public enum ResizePreset: String, CaseIterable, Identifiable, Sendable {
    case original
    case scale75
    case scale50
    case max1080p
    case max4K

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original: return "Original Size (100%)"
        case .scale75: return "75% Scale"
        case .scale50: return "50% Scale"
        case .max1080p: return "Max 1080p (1920x1080)"
        case .max4K: return "Max 4K (3840x2160)"
        }
    }
}

public enum CropPreset: String, CaseIterable, Identifiable, Sendable {
    case none
    case square1x1
    case landscape16x9
    case portrait9x16
    case standard4x3

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "No Crop (Full Image)"
        case .square1x1: return "1:1 Square"
        case .landscape16x9: return "16:9 Landscape"
        case .portrait9x16: return "9:16 Portrait"
        case .standard4x3: return "4:3 Standard"
        }
    }
}

public struct CustomCropRegion: Sendable {
    public var normX: Double
    public var normY: Double
    public var normW: Double
    public var normH: Double

    public init(normX: Double = 0.0, normY: Double = 0.0, normW: Double = 1.0, normH: Double = 1.0) {
        self.normX = max(0, min(1, normX))
        self.normY = max(0, min(1, normY))
        self.normW = max(0.01, min(1 - normX, normW))
        self.normH = max(0.01, min(1 - normY, normH))
    }
}

public final class ImageConverterService {
    public static func convertImage(
        at url: URL,
        targetFormat: ImageFormat,
        preset: ResizePreset,
        cropPreset: CropPreset = .none,
        quality: Double = 0.85
    ) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw NSError(domain: "ImageConverterService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image at \(url.path)"])
        }

        let workingImage = applyCrop(cgImage, preset: cropPreset)
        let targetSize = targetSize(for: workingImage, preset: preset)
        let resizedImage = try renderResizedImage(workingImage, targetSize: targetSize)
        let destURL = uniqueDestinationURL(for: url, format: targetFormat)
        try writeImage(resizedImage, to: destURL, format: targetFormat, quality: quality)
        return destURL
    }

    private static func applyCrop(_ cgImage: CGImage, preset: CropPreset) -> CGImage {
        guard preset != .none else { return cgImage }

        let fullW = CGFloat(cgImage.width)
        let fullH = CGFloat(cgImage.height)
        var cropW = fullW
        var cropH = fullH

        switch preset {
        case .square1x1:
            let side = min(fullW, fullH)
            cropW = side
            cropH = side
        case .landscape16x9:
            (cropW, cropH) = croppedDimensions(fullW: fullW, fullH: fullH, targetAspect: 16.0 / 9.0)
        case .portrait9x16:
            (cropW, cropH) = croppedDimensions(fullW: fullW, fullH: fullH, targetAspect: 9.0 / 16.0)
        case .standard4x3:
            (cropW, cropH) = croppedDimensions(fullW: fullW, fullH: fullH, targetAspect: 4.0 / 3.0)
        case .none:
            break
        }

        let cropRect = CGRect(x: (fullW - cropW) / 2.0, y: (fullH - cropH) / 2.0, width: cropW, height: cropH)
        return cgImage.cropping(to: cropRect) ?? cgImage
    }

    private static func croppedDimensions(fullW: CGFloat, fullH: CGFloat, targetAspect: CGFloat) -> (CGFloat, CGFloat) {
        if (fullW / fullH) > targetAspect {
            return (fullH * targetAspect, fullH)
        } else {
            return (fullW, fullW / targetAspect)
        }
    }

    private static func targetSize(for image: CGImage, preset: ResizePreset) -> CGSize {
        let origWidth = CGFloat(image.width)
        let origHeight = CGFloat(image.height)

        switch preset {
        case .original:
            return CGSize(width: origWidth, height: origHeight)
        case .scale75:
            return CGSize(width: origWidth * 0.75, height: origHeight * 0.75)
        case .scale50:
            return CGSize(width: origWidth * 0.50, height: origHeight * 0.50)
        case .max1080p:
            return constrainedSize(origWidth: origWidth, origHeight: origHeight, maxWidth: 1920, maxHeight: 1080)
        case .max4K:
            return constrainedSize(origWidth: origWidth, origHeight: origHeight, maxWidth: 3840, maxHeight: 2160)
        }
    }

    private static func constrainedSize(origWidth: CGFloat, origHeight: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard origWidth > maxWidth || origHeight > maxHeight else {
            return CGSize(width: origWidth, height: origHeight)
        }
        let aspect = origWidth / origHeight
        if aspect > (maxWidth / maxHeight) {
            return CGSize(width: maxWidth, height: maxWidth / aspect)
        } else {
            return CGSize(width: maxHeight * aspect, height: maxHeight)
        }
    }

    private static func renderResizedImage(_ image: CGImage, targetSize: CGSize) throws -> CGImage {
        let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        guard let ctx = context else {
            throw NSError(domain: "ImageConverterService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context"])
        }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(origin: .zero, size: targetSize))

        guard let resizedImage = ctx.makeImage() else {
            throw NSError(domain: "ImageConverterService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to render resized image"])
        }
        return resizedImage
    }

    private static func uniqueDestinationURL(for url: URL, format: ImageFormat) -> URL {
        let parentFolder = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        var destURL = parentFolder.appendingPathComponent("\(baseName)_converted.\(format.fileExtension)")

        var counter = 2
        while FileManager.default.fileExists(atPath: destURL.path) {
            destURL = parentFolder.appendingPathComponent("\(baseName)_converted_\(counter).\(format.fileExtension)")
            counter += 1
        }
        return destURL
    }

    private static func writeImage(_ image: CGImage, to destURL: URL, format: ImageFormat, quality: Double) throws {
        guard let destination = CGImageDestinationCreateWithURL(destURL as CFURL, format.utType.identifier as CFString, 1, nil) else {
            throw NSError(domain: "ImageConverterService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "ImageConverterService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image destination"])
        }
    }
}
