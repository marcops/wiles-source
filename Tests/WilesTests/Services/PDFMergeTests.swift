import AppKit
import Foundation
import PDFKit
@testable import Wiles

@MainActor
public struct PDFMergeTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

        let unsupportedFile = tempDir.appendingPathComponent("merge_sample.txt")
        try? "not an image or pdf".write(to: unsupportedFile, atomically: true, encoding: .utf8)

        await runScenarios(tempDir: tempDir, imgFile: imgFile, unsupportedFile: unsupportedFile)
        await runWriteFailureScenario(imgFile: imgFile)
    }

    /// Covers mergeFiles' "guard outputPDF.write(to: destURL) else { throw ... }" branch: a
    /// destination folder the process can't write into makes PDFDocument.write(to:) fail even though
    /// page assembly itself succeeds.
    private static func runWriteFailureScenario(imgFile: URL) async {
        let readOnlyDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: readOnlyDir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnlyDir.path)
            try? FileManager.default.removeItem(at: readOnlyDir)
        }

        var threw = false
        do {
            _ = try await PDFMergeService.mergeFiles(urls: [imgFile], in: readOnlyDir, outputName: "WontWrite.pdf")
        } catch {
            threw = true
        }
        TestReporter.report("PDFMerge", "NEG: mergeFiles throws when writing the merged PDF to a read-only destination folder fails", result: threw)
    }

    private static func runScenarios(tempDir: URL, imgFile: URL, unsupportedFile: URL) async {
        await runBasicScenarios(tempDir: tempDir, imgFile: imgFile)
        await runUnsupportedFileScenarios(tempDir: tempDir, imgFile: imgFile, unsupportedFile: unsupportedFile)
    }

    private static func runBasicScenarios(tempDir: URL, imgFile: URL) async {
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
                result: defaultNamed.lastPathComponent.hasPrefix("Merged_"))
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
                && first?.lastPathComponent == "DupeMerged.pdf" && second?.lastPathComponent == "DupeMerged 2.pdf")

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

    private static func runUnsupportedFileScenarios(tempDir: URL, imgFile: URL, unsupportedFile: URL) async {
        // NEG: a file whose extension isn't "pdf" and can't be loaded as an NSImage (appendPages'
        // else-if branch fails both checks) is skipped, contributing zero pages. Writing a
        // zero-page PDFDocument doesn't fail — it silently produces a 1-page blank PDF — so
        // mergeFiles throws instead of writing that unrequested blank page to disk.
        var unsupportedThrew = false
        do {
            _ = try await PDFMergeService.mergeFiles(urls: [unsupportedFile], in: tempDir, outputName: "UnsupportedOnly.pdf")
        } catch {
            unsupportedThrew = true
        }
        TestReporter.report(
            "PDFMerge", "NEG: mergeFiles with only an unsupported file type throws instead of writing a blank PDF",
            result: unsupportedThrew)

        // POS: mixing a valid image with an unsupported file only contributes a page for the valid
        // one — appendPages' pageIndex accumulator must skip the failed entry without leaving a gap.
        if let mixed = try? await PDFMergeService.mergeFiles(urls: [imgFile, unsupportedFile], in: tempDir, outputName: "Mixed.pdf"),
           let mixedDoc = PDFDocument(url: mixed) {
            TestReporter.report(
                "PDFMerge",
                "POS: merging a valid image alongside an unsupported file only includes the valid file's page",
                result: mixedDoc.pageCount == 1)
        } else {
            TestReporter.report("PDFMerge", "POS: merging a valid image alongside an unsupported file only includes the valid file's page", result: false)
        }
    }
}
