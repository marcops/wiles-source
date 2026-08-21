import AppKit
import Foundation

/// The stored `NSImage` is only ever mutated once, in `OpenWithService.availableApplications`,
/// before the `ApplicationApp` wrapping it is constructed (`icon.size = ...` runs on line 23,
/// the `ApplicationApp(...)` init on line 25) — every call site afterward (context menus, "Open
/// With" lists) only reads `.name`/`.url`/`.icon`, never calls a mutating method on the image
/// itself. Safe to share across actors.
public struct ApplicationApp: Identifiable, @unchecked Sendable {
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
