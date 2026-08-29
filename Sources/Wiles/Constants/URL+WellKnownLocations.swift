import Foundation

public extension URL {
    static let userHome: URL = FileManager.default.homeDirectoryForCurrentUser
    /// Falls back to `~/.Trash` (never a hardcoded `/Users/...` string) if the API returns nothing.
    static let userTrash: URL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
}
