import Foundation
import AppKit

public struct ApplicationApp: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let icon: NSImage
    public let url: URL

    public init(id: String, name: String, icon: NSImage, url: URL) {
        self.id = id
        self.name = name
        self.icon = icon
        self.url = url
    }
}
