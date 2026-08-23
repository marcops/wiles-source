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
            if let formattedSize = formattedSize(of: fileSystem.items) {
                return String(format: tr(.itemsCountWithSize), totalCount, formattedSize)
            }
            return String(format: tr(.itemsCount), totalCount)
        } else {
            let selItems = fileSystem.items.filter { selection.selectedURLs.contains($0.url) }
            if let formattedSize = formattedSize(of: selItems) {
                return String(format: tr(.selectionCountWithSize), selCount, totalCount, formattedSize)
            }
            return String(format: tr(.selectionCount), selCount, totalCount)
        }
    }

    /// `nil` when `items` contains no files with a nonzero total size (an empty/all-directories
    /// selection) — lets both `statusText` branches share one "reduce → format" shape.
    private func formattedSize(of items: [FileItem]) -> String? {
        let totalSize = items.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
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
