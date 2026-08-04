@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct FileMetadataTests {
    public static func run() async {
        await testFetchPropertiesForRealFile()
        await testFetchPropertiesForNonExistentFileDoesNotCrash()
        await testKindIsResolvedForRegularFile()
        await testDimensionsAreResolvedForRealImage()
    }

    private static func testFetchPropertiesForRealFile() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("metadata_test.txt")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)

        let props = await FileMetadataService.shared.fetchProperties(for: file)
        report("FileMetadata", "POS: owner name is resolved for a real file", result: props.ownerName != nil && !(props.ownerName ?? "").isEmpty)
        report("FileMetadata", "POS: POSIX permissions string has the expected rwx-style length", result: (props.posixPermissions ?? "").count == 9)
    }

    private static func testFetchPropertiesForNonExistentFileDoesNotCrash() async {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString).txt")
        let props = await FileMetadataService.shared.fetchProperties(for: missing)
        report("FileMetadata", "NEG: non-existent file returns nil owner/permissions instead of crashing", result: props.ownerName == nil && props.posixPermissions == nil)
    }

    private static func testKindIsResolvedForRegularFile() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("kind_test.txt")
        try? "hello world".write(to: file, atomically: true, encoding: .utf8)

        let props = await FileMetadataService.shared.fetchProperties(for: file)
        report("FileMetadata", "POS: localized kind description is resolved for a real file", result: props.kind != nil && !(props.kind ?? "").isEmpty)
    }

    private static func testDimensionsAreResolvedForRealImage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("dimensions_test.png")
        let image = NSImage(size: NSSize(width: 64, height: 32))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 32).fill()
        image.unlockFocus()
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: file)
        }

        let props = await FileMetadataService.shared.fetchProperties(for: file)
        report("FileMetadata", "POS: pixel dimensions are resolved for a real PNG image and formatted with ×", result: (props.dimensions ?? "").contains("×"))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
