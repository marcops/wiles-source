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
            if let formattedSize = formattedSize(ofBytes: fileSystem.totalFileSizeBytes) {
                return String(format: tr(.itemsCountWithSize), totalCount, formattedSize)
            }
            return String(format: tr(.itemsCount), totalCount)
        } else {
            let selectedBytes = fileSystem.items.reduce(0) { sum, item in
                item.isDirectory || !selection.selectedURLs.contains(item.url) ? sum : sum + item.size
            }
            if let formattedSize = formattedSize(ofBytes: selectedBytes) {
                return String(format: tr(.selectionCountWithSize), selCount, totalCount, formattedSize)
            }
            return String(format: tr(.selectionCount), selCount, totalCount)
        }
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
