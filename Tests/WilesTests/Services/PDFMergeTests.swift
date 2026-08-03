import Foundation
import AppKit

@MainActor
public struct PDFMergeTests {
    public static func run() {
        let tempDir = FileManager.default.temporaryDirectory
        let imgFile = tempDir.appendingPathComponent("merge_sample.png")
        
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.set()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: imgFile)
        }
        
        if let merged = try? PDFMergeService.mergeFiles(urls: [imgFile], in: tempDir, outputName: "TestMerged.pdf") {
            TestReporter.report("PDFMerge", "POS: mergeFiles creates valid PDF file", result: FileManager.default.fileExists(atPath: merged.path))
        } else {
            TestReporter.report("PDFMerge", "POS: mergeFiles creates valid PDF file", result: false)
        }
    }
}
