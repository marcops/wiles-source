@testable import Wiles
import Foundation
import AppKit
import PDFKit

@MainActor
public struct PDFMergeTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imgFile = tempDir.appendingPathComponent("merge_sample.png")

        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.set()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()

        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: imgFile)
        }

        await runScenarios(tempDir: tempDir, imgFile: imgFile)
    }

    private static func runScenarios(tempDir: URL, imgFile: URL) async {
        if let merged = try? await PDFMergeService.mergeFiles(urls: [imgFile], in: tempDir, outputName: "TestMerged.pdf") {
            TestReporter.report("PDFMerge", "POS: mergeFiles creates valid PDF file", result: FileManager.default.fileExists(atPath: merged.path))
        } else {
            TestReporter.report("PDFMerge", "POS: mergeFiles creates valid PDF file", result: false)
        }

        // NEG: empty URL list throws instead of producing an empty PDF
        var threw = false
        do {
            _ = try await PDFMergeService.mergeFiles(urls: [], in: tempDir, outputName: "Empty.pdf")
        } catch {
            threw = true
        }
        TestReporter.report("PDFMerge", "NEG: mergeFiles with an empty URL list throws", result: threw)

        // POS: default output name (nil) generates a "Merged_<timestamp>.pdf" file
        if let defaultNamed = try? await PDFMergeService.mergeFiles(urls: [imgFile], in: tempDir, outputName: nil) {
            TestReporter.report(
                "PDFMerge",
                "POS: mergeFiles with no outputName generates a default \"Merged_...\" name",
                result: defaultNamed.lastPathComponent.hasPrefix("Merged_")
            )
        } else {
            TestReporter.report("PDFMerge", "POS: mergeFiles with no outputName generates a default \"Merged_...\" name", result: false)
        }

        // POS: merging the same output name twice avoids overwriting via a numeric suffix
        let dupeName = "DupeMerged.pdf"
        let first = try? await PDFMergeService.mergeFiles(urls: [imgFile], in: tempDir, outputName: dupeName)
        let second = try? await PDFMergeService.mergeFiles(urls: [imgFile], in: tempDir, outputName: dupeName)
        TestReporter.report(
            "PDFMerge", "POS: mergeFiles avoids overwriting an existing output file by appending a counter",
            result: first != nil && second != nil && first?.lastPathComponent != second?.lastPathComponent
                && first?.lastPathComponent == "DupeMerged.pdf" && second?.lastPathComponent == "DupeMerged 2.pdf"
        )

        // POS: merging multiple PDFs concatenates their pages into one document
        if let pdfA = try? await PDFMergeService.mergeFiles(urls: [imgFile], in: tempDir, outputName: "PageA.pdf"),
           let pdfB = try? await PDFMergeService.mergeFiles(urls: [imgFile], in: tempDir, outputName: "PageB.pdf"),
           let combined = try? await PDFMergeService.mergeFiles(urls: [pdfA, pdfB], in: tempDir, outputName: "Combined.pdf"),
           let combinedDoc = PDFDocument(url: combined) {
            TestReporter.report("PDFMerge", "POS: merging two single-page PDFs produces a 2-page combined document", result: combinedDoc.pageCount == 2)
        } else {
            TestReporter.report("PDFMerge", "POS: merging two single-page PDFs produces a 2-page combined document", result: false)
        }
    }
}
