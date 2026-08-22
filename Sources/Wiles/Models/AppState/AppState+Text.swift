import Foundation

public extension AppState {
    /// Builds a menu-item label combining a localized action name with its keyboard-shortcut hint
    /// (e.g. "Paste (Cmd+V)"). The shortcut itself is a keyboard symbol, not translated prose — this
    /// only centralizes the "(...)" wrapping previously hand-concatenated at each call site.
    func trWithShortcutHint(_ key: L10n.Key, shortcut: String) -> String {
        "\(tr(key)) (\(shortcut))"
    }

    var statusText: String {
        let totalCount = fileSystem.items.count
        let selCount = selection.selectedURLs.count

        if selCount == 0 {
            let totalFilesSize = fileSystem.items.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
            if totalFilesSize > 0 {
                let formattedSize = ByteCountFormatter.string(fromByteCount: totalFilesSize, countStyle: .file)
                return String(format: tr(.itemsCountWithSize), totalCount, formattedSize)
            }
            return String(format: tr(.itemsCount), totalCount)
        } else {
            let selItems = fileSystem.items.filter { selection.selectedURLs.contains($0.url) }
            let selFilesSize = selItems.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
            if selFilesSize > 0 {
                let formattedSize = ByteCountFormatter.string(fromByteCount: selFilesSize, countStyle: .file)
                return "\(selCount) / \(totalCount) (\(formattedSize))"
            } else {
                return "\(selCount) / \(totalCount)"
            }
        }
    }

    /// Reads volume free-space asynchronously off the main thread. `resourceValues(forKeys:)` is a
    /// synchronous disk/syscall — on a slow SMB mount it can block for seconds, so this must never be
    /// called as a computed property from an `@Observable` render path. Callers store the result in
    /// `@State` via `.task` instead of reading this synchronously in `body`.
    func loadFreeSpaceText() async -> String? {
        let url = navigation.currentURL
        let capacity = await Task.detached(priority: .utility) { () -> Int? in
            (try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]))?.volumeAvailableCapacity
        }.value
        guard let capacity else { return nil }
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(capacity), countStyle: .file)
        return "\(formatted) \(tr(.freeSpace))"
    }
}
