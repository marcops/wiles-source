import SwiftUI

/// One read/toggle surface over the two directory trees' different "expanded folders" stores: the
/// folder picker's `Set<URL>` view state and the sidebar's persisted `Set<String>` of folder paths.
struct DirectoryTreeExpansion {
    let isExpanded: (URL) -> Bool
    let toggle: (URL) -> Void

    /// Folder-picker backing: expansion tracked by full folder `URL`.
    static func urlSet(_ expanded: Binding<Set<URL>>) -> Self {
        Self(
            isExpanded: { expanded.wrappedValue.contains($0) },
            toggle: { url in
                if expanded.wrappedValue.contains(url) {
                    expanded.wrappedValue.remove(url)
                } else {
                    expanded.wrappedValue.insert(url)
                }
            })
    }

    /// Sidebar backing: expansion tracked by folder path string, matching the persisted set.
    static func pathSet(_ expanded: Binding<Set<String>>) -> Self {
        Self(
            isExpanded: { expanded.wrappedValue.contains($0.path) },
            toggle: { url in
                if expanded.wrappedValue.contains(url.path) {
                    expanded.wrappedValue.remove(url.path)
                } else {
                    expanded.wrappedValue.insert(url.path)
                }
            })
    }
}
