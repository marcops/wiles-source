import Foundation

public struct NetworkShare: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}
