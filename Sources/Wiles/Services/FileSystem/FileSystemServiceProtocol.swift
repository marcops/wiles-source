import Foundation

public protocol FileSystemServiceProtocol: Sendable {
    static func loadDirectoryContents(at url: URL, options: DirectoryLoadOptions) async throws -> [FileItem]
    static func loadRecursiveSearchResults(
        at root: URL,
        options: DirectoryLoadOptions,
        includeHidden: Bool,
        onBatch: @escaping @Sendable ([FileItem]) -> Void) async throws
    @discardableResult
    static func copyItem(at sourceURL: URL, toFolder destinationFolderURL: URL) throws -> URL
    @discardableResult
    static func moveItem(at sourceURL: URL, toFolder destinationFolderURL: URL) throws -> URL
    @discardableResult
    static func moveToTrash(url: URL) throws -> URL
    @discardableResult
    static func renameItem(at url: URL, newName: String) throws -> URL
    @discardableResult
    static func createDirectory(at parentURL: URL, name: String) throws -> URL
    @discardableResult
    static func createUniqueDirectory(at parentURL: URL, baseName: String) throws -> URL
    static func compressToZIP(urls: [URL], in destinationFolder: URL) throws
    static func extractZIP(archiveURL: URL, to destinationFolder: URL) throws
    static func setTags(for url: URL, tags: [String]) throws
}
