@testable import Wiles
import Foundation
import AppKit

/// Covers `FileMetadataTooltipService.tooltip(for:)`'s correctness — in particular the private
/// `pixelDimensions(for:)` helper, exercised indirectly since it's only reachable through the
/// public `tooltip(for:)` entry point. The `Task.detached` wrapping around the CGImageSource read
/// is not independently testable (no timing/dispatch harness), but the parsed "W x H" output it
/// produces is a pure, deterministic result of a real image file and is fully verifiable here.
@MainActor
public struct FileMetadataTooltipServiceTests {
    public static func run() async {
        await testTooltipIncludesPixelDimensionsForRealImage()
        await testTooltipOmitsDimensionsForNonImageFile()
        await testTooltipForDirectoryOmitsDimensions()
    }

    private static func makePNG(width: Int, height: Int, at url: URL) {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
    }

    private static func testTooltipIncludesPixelDimensionsForRealImage() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("tooltip_dims.png")
        makePNG(width: 48, height: 24, at: file)

        let item = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item)

        report(
            "FileMetadataTooltipService",
            "POS: tooltip(for:) includes the real pixel dimensions line for an image file",
            result: tooltip.contains("48 x 24")
        )
    }

    private static func testTooltipOmitsDimensionsForNonImageFile() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("notes.txt")
        try? "hello world".write(to: file, atomically: true, encoding: .utf8)

        let item = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item)

        report(
            "FileMetadataTooltipService",
            "NEG: tooltip(for:) does not include a dimensions-shaped line for a plain text file",
            result: !tooltip.contains(" x ")
        )
    }

    private static func testTooltipForDirectoryOmitsDimensions() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = FileItem(url: dir, icon: NSWorkspace.shared.icon(forFile: dir.path))
        let tooltip = await FileMetadataTooltipService.tooltip(for: item)

        report(
            "FileMetadataTooltipService",
            "NEG: tooltip(for:) for a directory reports Folder and never attempts image parsing",
            result: tooltip.contains("Folder") && !tooltip.contains(" x ")
        )
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
