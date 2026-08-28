import Foundation

public protocol ArchiveInspectionServiceProtocol: Sendable {
    static func listEntries(in archiveURL: URL) async throws -> [ArchiveEntryItem]
    static func extractSingleEntry(from archiveURL: URL, entryPath: String, to destinationFolder: URL) async throws -> URL
}
