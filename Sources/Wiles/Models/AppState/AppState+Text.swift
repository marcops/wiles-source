import Foundation

public extension AppState {
    /// Builds a menu-item label combining a localized action name with its keyboard-shortcut hint
    /// (e.g. "Paste (Cmd+V)"). The shortcut itself is a keyboard symbol, not translated prose — this
    /// only centralizes the "(...)" wrapping previously hand-concatenated at each call site.
    func trWithShortcutHint(_ key: L10n.Key, shortcut: String) -> String {
        "\(tr(key)) (\(shortcut))"
    }

    var statusText: String {
        let base = itemCountStatusText
        guard fileSystem.resultsTruncated else { return base }
        return base + " · " + String(format: tr(.resultsTruncatedNotice), fileSystem.items.count)
    }

    private var itemCountStatusText: String {
        let totalCount = fileSystem.items.count
        let selCount = selection.selectedURLs.count

        if selCount == 0 {
            if let formattedSize = formattedSize(ofBytes: fileSystem.totalFileSizeBytes) {
                return String(format: tr(.itemsCountWithSize), totalCount, formattedSize)
            }
            return String(format: tr(.itemsCount), totalCount)
        } else {
            if let formattedSize = formattedSize(ofBytes: selectedFileSizeBytes) {
                return String(format: tr(.selectionCountWithSize), selCount, totalCount, formattedSize)
            }
            return String(format: tr(.selectionCount), selCount, totalCount)
        }
    }

    /// Sum of the selected non-directory items' sizes. Cached on `SelectionStore` and recomputed
    /// only when the selection or the item list changes, not on every footer render — a "Select All"
    /// in a 10k folder was previously an O(n) reduce + per-item `Set` lookup every render.
    var selectedFileSizeBytes: Int64 {
        if let cached = selection.cachedSelectedFileSizeBytes {
            return cached
        }
        let total = selection.selectedURLs.reduce(Int64(0)) { partial, url in
            guard let item = fileSystem.itemsByURL[url], !item.isDirectory else { return partial }
            return partial + item.size
        }
        selection.cachedSelectedFileSizeBytes = total
        return total
    }

    /// `nil` for a zero total (an empty/all-directories set) — lets both `statusText` branches
    /// share one "format or fall back" shape.
    private func formattedSize(ofBytes totalSize: Int64) -> String? {
        guard totalSize > 0 else { return nil }
        return ByteFormat.fileSize(totalSize)
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
        let formatted = ByteFormat.fileSize(Int64(capacity))
        return String(format: tr(.freeSpaceFormat), formatted)
    }
}
