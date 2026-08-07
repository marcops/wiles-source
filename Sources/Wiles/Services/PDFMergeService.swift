import Foundation
import AppKit
import PDFKit

public protocol PDFMergeServiceProtocol: Sendable {
    static func mergeFiles(urls: [URL], in destinationFolder: URL, outputName: String?) async throws -> URL
}

public final class PDFMergeService: PDFMergeServiceProtocol, Sendable {
    /// Not @MainActor, and the heavy work runs inside Task.detached: looping over files calling
    /// NSImage(contentsOf:) synchronously decompresses each image's full bitmap into RAM — for
    /// several large photos this alone can take seconds, and doing it on @MainActor (as this used
    /// to be declared) froze the entire UI for that whole duration.
    public static func mergeFiles(urls: [URL], in destinationFolder: URL, outputName: String? = nil) async throws -> URL {
        guard !urls.isEmpty else {
            throw NSError(domain: "PDFMergeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No files provided."])
        }

        return try await Task.detached(priority: .userInitiated) {
            let outputPDF = PDFDocument()
            var pageIndex = 0

            for url in urls {
                pageIndex = appendPages(from: url, into: outputPDF, startingAt: pageIndex)
            }

            let destURL = uniqueDestination(for: outputName, in: destinationFolder)
            guard outputPDF.write(to: destURL) else {
                throw NSError(domain: "PDFMergeService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not write the merged PDF to disk."])
            }
            return destURL
        }.value
    }

    /// autoreleasepool ensures each image's uncompressed bitmap (which can be tens of MB for a
    /// single large photo) is freed immediately after its page is inserted, instead of all of
    /// them accumulating until the whole merge loop finishes.
    private static func appendPages(from url: URL, into outputPDF: PDFDocument, startingAt pageIndex: Int) -> Int {
        var pageIndex = pageIndex
        autoreleasepool {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                if let doc = PDFDocument(url: url) {
                    for pageNum in 0..<doc.pageCount {
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
        var destURL = destinationFolder.appendingPathComponent(fileName)
        var counter = 2
        while FileManager.default.fileExists(atPath: destURL.path) {
            let baseName = (fileName as NSString).deletingPathExtension
            destURL = destinationFolder.appendingPathComponent("\(baseName) \(counter).pdf")
            counter += 1
        }
        return destURL
    }
}
