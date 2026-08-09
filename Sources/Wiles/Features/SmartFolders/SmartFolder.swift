import Foundation

public struct SmartFolder: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var searchQuery: String
    public var scopePath: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, icon: String = "folder.badge.gearshape", searchQuery: String, scopePath: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.searchQuery = searchQuery
        self.scopePath = scopePath
        self.createdAt = createdAt
    }
}
