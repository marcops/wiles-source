import Foundation

public protocol PDFMergeServiceProtocol: Sendable {
    static func mergeFiles(urls: [URL], in destinationFolder: URL, outputName: String?) async throws -> URL
}
