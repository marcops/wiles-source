import Foundation
import AppKit
import PDFKit

@MainActor
public protocol PDFMergeServiceProtocol: Sendable {
    static func mergeFiles(urls: [URL], in destinationFolder: URL, outputName: String?) throws -> URL
}

public final class PDFMergeService: PDFMergeServiceProtocol, Sendable {
    @MainActor
    public static func mergeFiles(urls: [URL], in destinationFolder: URL, outputName: String? = nil) throws -> URL {
        guard !urls.isEmpty else {
            throw NSError(domain: "PDFMergeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No files provided."])
        }
        
        let outputPDF = PDFDocument()
        var pageIndex = 0
        
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                if let doc = PDFDocument(url: url) {
                    for i in 0..<doc.pageCount {
                        if let page = doc.page(at: i) {
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
        
        let fileName = outputName ?? "Merged_\(Int(Date().timeIntervalSince1970)).pdf"
        var destURL = destinationFolder.appendingPathComponent(fileName)
        var counter = 2
        while FileManager.default.fileExists(atPath: destURL.path) {
            let baseName = (fileName as NSString).deletingPathExtension
            destURL = destinationFolder.appendingPathComponent("\(baseName) \(counter).pdf")
            counter += 1
        }
        
        outputPDF.write(to: destURL)
        return destURL
    }
}
