import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

public enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg = "jpeg"
    case png = "png"
    case heic = "heic"
    case tiff = "tiff"
    
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
    case original = "original"
    case scale75 = "scale75"
    case scale50 = "scale50"
    case max1080p = "max1080p"
    case max4K = "max4K"
    case custom = "custom"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .original: return "Original Size (100%)"
        case .scale75: return "75% Scale"
        case .scale50: return "50% Scale"
        case .max1080p: return "Max 1080p (1920x1080)"
        case .max4K: return "Max 4K (3840x2160)"
        case .custom: return "Custom Dimensions (px)"
        }
    }
}

public enum CropPreset: String, CaseIterable, Identifiable, Sendable {
    case none = "none"
    case square1x1 = "square1x1"
    case landscape16x9 = "landscape16x9"
    case portrait9x16 = "portrait9x16"
    case standard4x3 = "standard4x3"
    case custom = "custom"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .none: return "No Crop (Full Image)"
        case .square1x1: return "1:1 Square"
        case .landscape16x9: return "16:9 Landscape"
        case .portrait9x16: return "9:16 Portrait"
        case .standard4x3: return "4:3 Standard"
        case .custom: return "Custom Selection / Drag"
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
        cropRegion: CustomCropRegion = CustomCropRegion(),
        customWidth: Int? = nil,
        customHeight: Int? = nil,
        quality: Double = 0.85
    ) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw NSError(domain: "ImageConverterService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image at \(url.path)"])
        }
        
        let fullW = CGFloat(cgImage.width)
        let fullH = CGFloat(cgImage.height)
        var workingImage = cgImage
        
        if cropPreset == .custom {
            let cropX = fullW * CGFloat(cropRegion.normX)
            let cropY = fullH * (1.0 - CGFloat(cropRegion.normY) - CGFloat(cropRegion.normH))
            let cropW = fullW * CGFloat(cropRegion.normW)
            let cropH = fullH * CGFloat(cropRegion.normH)
            
            let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
            if let cropped = cgImage.cropping(to: cropRect) {
                workingImage = cropped
            }
        } else if cropPreset != .none {
            var cropW = fullW
            var cropH = fullH
            
            switch cropPreset {
            case .square1x1:
                let side = min(fullW, fullH)
                cropW = side
                cropH = side
            case .landscape16x9:
                let targetAspect: CGFloat = 16.0 / 9.0
                if (fullW / fullH) > targetAspect {
                    cropH = fullH
                    cropW = fullH * targetAspect
                } else {
                    cropW = fullW
                    cropH = fullW / targetAspect
                }
            case .portrait9x16:
                let targetAspect: CGFloat = 9.0 / 16.0
                if (fullW / fullH) > targetAspect {
                    cropH = fullH
                    cropW = fullH * targetAspect
                } else {
                    cropW = fullW
                    cropH = fullW / targetAspect
                }
            case .standard4x3:
                let targetAspect: CGFloat = 4.0 / 3.0
                if (fullW / fullH) > targetAspect {
                    cropH = fullH
                    cropW = fullH * targetAspect
                } else {
                    cropW = fullW
                    cropH = fullW / targetAspect
                }
            default: break
            }
            
            let cropRect = CGRect(x: (fullW - cropW) / 2.0, y: (fullH - cropH) / 2.0, width: cropW, height: cropH)
            if let cropped = cgImage.cropping(to: cropRect) {
                workingImage = cropped
            }
        }
        
        let origWidth = CGFloat(workingImage.width)
        let origHeight = CGFloat(workingImage.height)
        var targetWidth = origWidth
        var targetHeight = origHeight
        
        switch preset {
        case .original:
            break
        case .scale75:
            targetWidth = origWidth * 0.75
            targetHeight = origHeight * 0.75
        case .scale50:
            targetWidth = origWidth * 0.50
            targetHeight = origHeight * 0.50
        case .max1080p:
            let aspect = origWidth / origHeight
            if origWidth > 1920 || origHeight > 1080 {
                if aspect > (1920.0 / 1080.0) {
                    targetWidth = 1920
                    targetHeight = 1920 / aspect
                } else {
                    targetHeight = 1080
                    targetWidth = 1080 * aspect
                }
            }
        case .max4K:
            let aspect = origWidth / origHeight
            if origWidth > 3840 || origHeight > 2160 {
                if aspect > (3840.0 / 2160.0) {
                    targetWidth = 3840
                    targetHeight = 3840 / aspect
                } else {
                    targetHeight = 2160
                    targetWidth = 2160 * aspect
                }
            }
        case .custom:
            if let cw = customWidth, cw > 0 { targetWidth = CGFloat(cw) }
            if let ch = customHeight, ch > 0 { targetHeight = CGFloat(ch) }
        }
        
        let context = CGContext(
            data: nil,
            width: Int(targetWidth),
            height: Int(targetHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let ctx = context else {
            throw NSError(domain: "ImageConverterService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context"])
        }
        
        ctx.interpolationQuality = .high
        ctx.draw(workingImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
        guard let resizedImage = ctx.makeImage() else {
            throw NSError(domain: "ImageConverterService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to render resized image"])
        }
        
        let parentFolder = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let newFileName = "\(baseName)_converted.\(targetFormat.fileExtension)"
        var destURL = parentFolder.appendingPathComponent(newFileName)
        
        var counter = 2
        while FileManager.default.fileExists(atPath: destURL.path) {
            destURL = parentFolder.appendingPathComponent("\(baseName)_converted_\(counter).\(targetFormat.fileExtension)")
            counter += 1
        }
        
        guard let destination = CGImageDestinationCreateWithURL(destURL as CFURL, targetFormat.utType.identifier as CFString, 1, nil) else {
            throw NSError(domain: "ImageConverterService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, resizedImage, options as CFDictionary)
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "ImageConverterService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image destination"])
        }
        
        return destURL
    }
}
