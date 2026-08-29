import Foundation

public struct ClipboardState: Sendable {
    public let urls: [URL]
    public let action: ClipboardAction
    /// Standardized `urls` as a set — `isCut` is called once per visible row per render, so the
    /// membership test must be O(1), not a linear scan of `urls`.
    private let standardizedURLSet: Set<URL>

    public init(urls: [URL], action: ClipboardAction) {
        let standardized = urls.map(\.standardizedFileURL)
        self.urls = standardized
        standardizedURLSet = Set(standardized)
        self.action = action
    }

    public func isCut(url: URL) -> Bool {
        guard action == .cut else { return false }
        return standardizedURLSet.contains(url.standardizedFileURL)
    }
}
