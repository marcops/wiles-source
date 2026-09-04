import Foundation

public struct NetworkShare: Identifiable, Hashable, Sendable {
    /// Content-derived, not a per-instance `UUID()`: the service rebuilds the array on every mDNS
    /// update, and a fresh id each time made `ForEach` recreate the whole sidebar Network section.
    public var id: String { "\(name)\n\(url.absoluteString)" }
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}
