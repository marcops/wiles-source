import Foundation

public struct ArchiveEntryItem: Identifiable, Sendable {
    public var id: String {
        path
    }

    public let path: String
    public let isDirectory: Bool
    public let name: String

    public init(path: String) {
        self.path = path
        isDirectory = path.hasSuffix("/")
        let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        name = (clean as NSString).lastPathComponent
    }
}
