import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

public enum ImageConverterService {
    public static func convertImage(
        at url: URL,
        targetFormat: ImageFormat,
        preset: ResizePreset,
        cropPreset: CropPreset = .none,
        quality: Double = 0.85) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw WilesError.localized(key: .imageConverterLoadFailed, arguments: [url.path])
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
            (fullH * targetAspect, fullH)
        } else {
            (fullW, fullW / targetAspect)
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

    private static let bitmapBitsPerComponent = 8

    private static func renderResizedImage(_ image: CGImage, targetSize: CGSize) throws -> CGImage {
        guard let ctx = bitmapContext(for: image, targetSize: targetSize) else {
            throw WilesError.localized(key: .imageConverterContextFailed, arguments: [])
        }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(origin: .zero, size: targetSize))

        guard let resizedImage = ctx.makeImage() else {
            throw WilesError.localized(key: .imageConverterRenderFailed, arguments: [])
        }
        return resizedImage
    }

    /// Renders in the source image's own color space (keeps Display-P3, grayscale, CMYK fidelity),
    /// falling back to sRGB-with-profile - never bare device RGB - when that space can't back one.
    private static func bitmapContext(for image: CGImage, targetSize: CGSize) -> CGContext? {
        if let ctx = sourceColorSpaceContext(for: image, targetSize: targetSize) {
            return ctx
        }
        let fallbackSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return makeBitmapContext(targetSize: targetSize, colorSpace: fallbackSpace, alphaInfo: .premultipliedLast)
    }

    private static func sourceColorSpaceContext(for image: CGImage, targetSize: CGSize) -> CGContext? {
        guard let sourceSpace = image.colorSpace else { return nil }
        guard let alphaInfo = bitmapAlphaInfo(for: image, colorSpace: sourceSpace) else { return nil }
        return makeBitmapContext(targetSize: targetSize, colorSpace: sourceSpace, alphaInfo: alphaInfo)
    }

    private static func makeBitmapContext(
        targetSize: CGSize,
        colorSpace: CGColorSpace,
        alphaInfo: CGImageAlphaInfo) -> CGContext? {
        CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: bitmapBitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: alphaInfo.rawValue)
    }

    /// The alpha layout a bitmap context can accept for a given source color-space model, or `nil`
    /// when the model can't back a bitmap context and the caller should fall back to sRGB.
    private static func bitmapAlphaInfo(for image: CGImage, colorSpace: CGColorSpace) -> CGImageAlphaInfo? {
        switch colorSpace.model {
        case .rgb:
            .premultipliedLast
        case .monochrome, .cmyk:
            imageHasAlpha(image) ? nil : CGImageAlphaInfo.none
        default:
            nil
        }
    }

    private static func imageHasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            false
        default:
            true
        }
    }

    private static func uniqueDestinationURL(for url: URL, format: ImageFormat) -> URL {
        let parentFolder = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let desiredURL = parentFolder.appendingPathComponent("\(baseName)_converted.\(format.fileExtension)")
        return UniqueFileNaming.uniqueURL(for: desiredURL, in: parentFolder, isDirectory: false)
    }

    private static func writeImage(_ image: CGImage, to destURL: URL, format: ImageFormat, quality: Double) throws {
        guard let destination = CGImageDestinationCreateWithURL(destURL as CFURL, format.utType.identifier as CFString, 1, nil) else {
            throw WilesError.localized(key: .imageConverterDestinationFailed, arguments: [])
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        if !CGImageDestinationFinalize(destination) {
            throw WilesError.localized(key: .imageConverterFinalizeFailed, arguments: [])
        }
    }
}
