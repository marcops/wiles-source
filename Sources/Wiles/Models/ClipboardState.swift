import Foundation

public enum ClipboardAction: Sendable {
    case cut
    case copy
}

public struct ClipboardState: Sendable {
    public let urls: [URL]
    public let action: ClipboardAction
    
    public init(urls: [URL], action: ClipboardAction) {
        self.urls = urls.map { $0.standardizedFileURL }
        self.action = action
    }
    
    public func isCut(url: URL) -> Bool {
        guard action == .cut else { return false }
        return urls.contains(url.standardizedFileURL)
    }
}
