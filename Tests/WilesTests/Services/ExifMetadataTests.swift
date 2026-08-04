@testable import Wiles
import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
public struct ExifMetadataTests {
    public static func run() {
        testNoExifReturnsNil()
        testRealExifDataIsExtracted()
        testNonImageFileReturnsNil()
        testNonexistentFileReturnsNil()
        testPartialExifDataExtractsLensAndGPSOnly()
        testEmptyISOArrayYieldsNilISO()
    }

    private static func testNonImageFileReturnsNil() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tempFile = dir.appendingPathComponent("not_an_image.txt")
        try? "this is plain text, not image data".data(using: .utf8)?.write(to: tempFile)

        let result = ExifMetadataService.extractExif(from: tempFile)
        TestReporter.report("ExifMetadata", "NEG: non-image file (plain text) returns nil without crashing", result: result == nil)
    }

    private static func testNonexistentFileReturnsNil() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let missingFile = dir.appendingPathComponent("does_not_exist.jpg")

        let result = ExifMetadataService.extractExif(from: missingFile)
        TestReporter.report("ExifMetadata", "NEG: nonexistent file URL returns nil without crashing", result: result == nil)
    }

    private static func testPartialExifDataExtractsLensAndGPSOnly() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tempFile = dir.appendingPathComponent("partial_exif.jpg")

        // Only lensModel and GPS present; no make/model/iso/aperture/focalLength/dateTime.
        let exifDict: [CFString: Any] = [
            kCGImagePropertyExifLensModel: "Wide Lens 24mm"
        ]
        let gpsDict: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 10.1234,
            kCGImagePropertyGPSLatitudeRef: "S",
            kCGImagePropertyGPSLongitude: 20.5678,
            kCGImagePropertyGPSLongitudeRef: "E"
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exifDict,
            kCGImagePropertyGPSDictionary: gpsDict
        ]

        guard let dest = CGImageDestinationCreateWithURL(tempFile as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            TestReporter.report("ExifMetadata", "POS: partial EXIF (lens + GPS only) extracts lens/GPS and leaves rest nil", result: false)
            return
        }

        let baseImage = NSImage(size: NSSize(width: 20, height: 20))
        baseImage.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 20, height: 20).fill()
        baseImage.unlockFocus()
        guard let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            TestReporter.report("ExifMetadata", "POS: partial EXIF (lens + GPS only) extracts lens/GPS and leaves rest nil", result: false)
            return
        }

        CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
        let finalized = CGImageDestinationFinalize(dest)

        guard finalized else {
            TestReporter.report("ExifMetadata", "POS: partial EXIF (lens + GPS only) extracts lens/GPS and leaves rest nil", result: false)
            return
        }

        let result = ExifMetadataService.extractExif(from: tempFile)

        let pos = result != nil
            && result?.lensModel == "Wide Lens 24mm"
            && result?.cameraMake == nil
            && result?.cameraModel == nil
            && result?.iso == nil
            && result?.aperture == nil
            && result?.focalLength == nil
            && result?.dateTimeOriginal == nil
            && (result?.gpsCoordinates ?? "").contains("10.1234")
            && (result?.gpsCoordinates ?? "").contains("S")
            && (result?.gpsCoordinates ?? "").contains("20.5678")
            && (result?.gpsCoordinates ?? "").contains("E")

        TestReporter.report("ExifMetadata", "POS: partial EXIF (lens + GPS only) extracts lens/GPS and leaves rest nil", result: pos)
    }

    private static func testEmptyISOArrayYieldsNilISO() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tempFile = dir.appendingPathComponent("empty_iso.jpg")

        // ISO array present but empty, plus a non-ISO field so extraction doesn't short-circuit to nil.
        let exifDict: [CFString: Any] = [
            kCGImagePropertyExifISOSpeedRatings: [Int](),
            kCGImagePropertyExifFNumber: 4.0
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exifDict
        ]

        guard let dest = CGImageDestinationCreateWithURL(tempFile as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            TestReporter.report("ExifMetadata", "NEG: empty ISO speed ratings array yields nil iso field (not crash/garbage)", result: false)
            return
        }

        let baseImage = NSImage(size: NSSize(width: 20, height: 20))
        baseImage.lockFocus()
        NSColor.green.setFill()
        NSRect(x: 0, y: 0, width: 20, height: 20).fill()
        baseImage.unlockFocus()
        guard let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            TestReporter.report("ExifMetadata", "NEG: empty ISO speed ratings array yields nil iso field (not crash/garbage)", result: false)
            return
        }

        CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
        let finalized = CGImageDestinationFinalize(dest)

        guard finalized else {
            TestReporter.report("ExifMetadata", "NEG: empty ISO speed ratings array yields nil iso field (not crash/garbage)", result: false)
            return
        }

        let result = ExifMetadataService.extractExif(from: tempFile)

        let neg = result != nil && result?.iso == nil && result?.aperture == "f/4.0"
        TestReporter.report("ExifMetadata", "NEG: empty ISO speed ratings array yields nil iso field (not crash/garbage)", result: neg)
    }

    private static func testNoExifReturnsNil() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tempFile = dir.appendingPathComponent("no_exif.png")
        let image = NSImage(size: NSSize(width: 50, height: 50))
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: tempFile)
        }

        let result = ExifMetadataService.extractExif(from: tempFile)
        TestReporter.report("ExifMetadata", "NEG: image with no EXIF/TIFF/GPS metadata returns nil", result: result == nil)
    }

    private static func testRealExifDataIsExtracted() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let tempFile = dir.appendingPathComponent("with_exif.jpg")

        let exifDict: [CFString: Any] = [
            kCGImagePropertyExifISOSpeedRatings: [200],
            kCGImagePropertyExifFNumber: 2.8,
            kCGImagePropertyExifFocalLength: 50.0,
            kCGImagePropertyExifDateTimeOriginal: "2024:01:15 10:30:00"
        ]
        let tiffDict: [CFString: Any] = [
            kCGImagePropertyTIFFMake: "TestCam",
            kCGImagePropertyTIFFModel: "Model X"
        ]
        let gpsDict: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 37.7749,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 122.4194,
            kCGImagePropertyGPSLongitudeRef: "W"
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exifDict,
            kCGImagePropertyTIFFDictionary: tiffDict,
            kCGImagePropertyGPSDictionary: gpsDict
        ]

        guard let dest = CGImageDestinationCreateWithURL(tempFile as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            TestReporter.report("ExifMetadata", "POS: real JPEG with embedded EXIF is parsed correctly", result: false)
            return
        }

        let baseImage = NSImage(size: NSSize(width: 20, height: 20))
        baseImage.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 20, height: 20).fill()
        baseImage.unlockFocus()
        guard let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            TestReporter.report("ExifMetadata", "POS: real JPEG with embedded EXIF is parsed correctly", result: false)
            return
        }

        CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
        let finalized = CGImageDestinationFinalize(dest)

        guard finalized else {
            TestReporter.report("ExifMetadata", "POS: real JPEG with embedded EXIF is parsed correctly", result: false)
            return
        }

        let result = ExifMetadataService.extractExif(from: tempFile)

        let pos = result?.cameraMake == "TestCam"
            && result?.cameraModel == "Model X"
            && result?.iso == "ISO 200"
            && result?.aperture == "f/2.8"
            && result?.focalLength == "50.0 mm"
            && result?.dateTimeOriginal == "2024:01:15 10:30:00"
            && (result?.gpsCoordinates ?? "").contains("37.7749")
            && (result?.gpsCoordinates ?? "").contains("N")
            && (result?.gpsCoordinates ?? "").contains("122.4194")
            && (result?.gpsCoordinates ?? "").contains("W")

        TestReporter.report("ExifMetadata", "POS: real JPEG with embedded EXIF is parsed correctly", result: pos)
    }
}
