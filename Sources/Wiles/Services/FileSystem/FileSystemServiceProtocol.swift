import Foundation
import AppKit

public protocol FileSystemServiceProtocol: Sendable {
    static func loadDirectoryContents(at url: URL, options: DirectoryLoadOptions) async -> [FileItem]
    static func copyItem(at sourceURL: URL, toFolder destinationFolderURL: URL) throws -> URL
    static func moveItem(at sourceURL: URL, toFolder destinationFolderURL: URL) throws -> URL
    static func moveToTrash(url: URL) throws -> URL
    static func writeToPasteboard(urls: [URL])
    static func readFromPasteboard() -> [URL]?
    static func copyFileContentToClipboard(url: URL)
    static func setTags(for url: URL, tags: [String]) throws
}
