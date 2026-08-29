import AppKit
import Foundation
import PDFKit

public final class PDFMergeService: Sendable {
    /// Not @MainActor, and the heavy work runs inside Task.detached: looping over files calling
    /// NSImage(contentsOf:) synchronously decompresses each image's full bitmap into RAM — for
    /// several large photos this alone can take seconds, and doing it on @MainActor (as this used
    /// to be declared) froze the entire UI for that whole duration.
    /// `skippedCount` is the number of inputs that contributed no pages (unreadable PDF / image) —
    /// the merge still produces a PDF from the rest; the caller can tell the user how many were dropped.
    public static func mergeFiles(urls: [URL], in destinationFolder: URL, outputName: String? = nil) async throws -> (url: URL, skippedCount: Int) {
        guard !urls.isEmpty else {
            throw WilesError.localized(key: .pdfMergeNoFilesProvided, arguments: [])
        }

        return try await Task.detached(priority: .userInitiated) {
            let outputPDF = PDFDocument()
            var pageIndex = 0
            var skippedCount = 0

            for url in urls {
                try Task.checkCancellation()
                let before = pageIndex
                pageIndex = try appendPages(from: url, into: outputPDF, startingAt: pageIndex)
                if pageIndex == before {
                    skippedCount += 1
                }
            }

            // PDFDocument.write(to:) does not fail for a zero-page document — on this
            // platform it silently produces a valid PDF with one blank page. Throw here
            // instead of letting that surprise the caller with an unrequested blank page.
            guard pageIndex > 0 else {
                throw WilesError.localized(key: .pdfMergeNoValidPages, arguments: [])
            }

            let destURL = uniqueDestination(for: outputName, in: destinationFolder)
            guard outputPDF.write(to: destURL) else {
                throw WilesError.localized(key: .pdfMergeWriteFailed, arguments: [])
            }
            return (destURL, skippedCount)
        }.value
    }

    /// autoreleasepool ensures each image's uncompressed bitmap (which can be tens of MB for a
    /// single large photo) is freed immediately after its page is inserted, instead of all of
    /// them accumulating until the whole merge loop finishes.
    private static func appendPages(from url: URL, into outputPDF: PDFDocument, startingAt pageIndex: Int) throws -> Int {
        var pageIndex = pageIndex
        try autoreleasepool {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                if let doc = PDFDocument(url: url) {
                    for pageNum in 0 ..< doc.pageCount {
                        try Task.checkCancellation()
                        if let page = doc.page(at: pageNum) {
                            outputPDF.insert(page, at: pageIndex)
                            pageIndex += 1
                        }
                    }
                }
            } else if let image = NSImage(contentsOf: url), let page = PDFPage(image: image) {
                outputPDF.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }
        return pageIndex
    }

    private static func uniqueDestination(for outputName: String?, in destinationFolder: URL) -> URL {
        let fileName = outputName ?? "Merged_\(Int(Date().timeIntervalSince1970)).pdf"
        let candidateURL = destinationFolder.appendingPathComponent(fileName)
        return UniqueFileNaming.uniqueURL(for: candidateURL, in: destinationFolder, isDirectory: false)
    }
}
