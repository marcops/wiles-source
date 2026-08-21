import Foundation

@MainActor
public protocol SmartFolderServiceProtocol: Sendable {
    static func loadSavedSmartFolders() -> [SmartFolder]
    static func saveSmartFolders(_ folders: [SmartFolder]) throws
    func executeQuery(for smartFolder: SmartFolder, completion: @escaping @Sendable ([FileItem]) -> Void)
    func executeContentQuery(queryText: String, in folderURL: URL, completion: @escaping @Sendable ([FileItem]) -> Void)
}
