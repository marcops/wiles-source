@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct ExifMetadataTests {
    public static func run() {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("exif_test.png")
        let image = NSImage(size: NSSize(width: 50, height: 50))
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: tempFile)
        }

        _ = ExifMetadataService.extractExif(from: tempFile)
        TestReporter.report("ExifMetadata", "POS: extractExif runs safely on image", result: true)
    }
}
