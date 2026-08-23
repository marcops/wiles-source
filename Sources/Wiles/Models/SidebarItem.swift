import Foundation

struct SidebarItem: Identifiable, Hashable {
    /// Clicking this row must hand off to `NSWorkspace.shared.open(_:)` (which macOS special-cases
    /// into the AirDrop browsing UI), never `navigateTo` — that browses into the bundle's contents
    /// like any other folder, since `fileExists(atPath:isDirectory:)` reports `.app` bundles as directories.
    static let airDropURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app")

    let name: String
    let iconName: String
    let url: URL

    /// Stable identity from `url` (not a random `UUID`) so SwiftUI's `ForEach` doesn't tear down
    /// and rebuild every sidebar row on each re-evaluation of the view properties that build these.
    var id: URL {
        url.standardizedFileURL
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url.standardizedFileURL == rhs.url.standardizedFileURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url.standardizedFileURL)
    }
}
