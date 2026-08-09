import Foundation

@MainActor
public protocol SmartFolderServiceProtocol: Sendable {
    static func loadSavedSmartFolders() -> [SmartFolder]
    static func saveSmartFolders(_ folders: [SmartFolder])
}
