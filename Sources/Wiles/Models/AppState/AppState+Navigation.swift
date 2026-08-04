import Foundation
import AppKit

extension AppState {
    public func navigateTo(_ url: URL, addToHistory: Bool = true) {
        if url == Self.recentsVirtualURL {
            if addToHistory && url != currentURL {
                historyBack.append(currentURL)
                historyForward.removeAll()
            }
            currentURL = url
            selectedURLs.removeAll()
            isSearching = false
            searchQuery = ""
            refreshCurrentDirectory()
            return
        }
        addToRecents(url)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            if addToHistory && url != currentURL {
                historyBack.append(currentURL)
                historyForward.removeAll()
            }
            currentURL = url.standardizedFileURL
            selectedURLs.removeAll()
            isSearching = false
            searchQuery = ""
            refreshCurrentDirectory()
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    public func goBack() {
        guard let prev = historyBack.popLast() else { return }
        historyForward.append(currentURL)
        navigateTo(prev, addToHistory: false)
    }

    public func goForward() {
        guard let next = historyForward.popLast() else { return }
        historyBack.append(currentURL)
        navigateTo(next, addToHistory: false)
    }

    public func goUp() {
        let parent = currentURL.deletingLastPathComponent()
        if parent != currentURL { navigateTo(parent) }
    }

    public func refreshCurrentDirectory() {
        isLoading = true
        let target = currentURL
        let hidden = showHiddenFiles
        let tags = showTags
        let query = searchQuery
        let sort = sortOption
        let asc = sortAscending

        startDirectoryMonitoring(for: target)

        if query.isEmpty, let cached = DirectoryCacheService.shared.cachedResult(for: target) {
            self.items = cached.items
            self.isLoading = false
            if self.viewMode == .list, self.selectedURLs.isEmpty, let first = cached.items.first {
                self.selectedURLs = [first.url]
            }
        } else {
            isLoading = true
        }

        Task {
            let loaded = await FileSystemService.loadDirectoryContents(
                at: target,
                options: DirectoryLoadOptions(showHidden: hidden, showTags: tags, searchQuery: query, sortOption: sort, sortAscending: asc)
            )
            if self.currentURL == target {
                self.items = loaded
                self.isLoading = false
                if self.viewMode == .list, self.selectedURLs.isEmpty, let first = loaded.first {
                    self.selectedURLs = [first.url]
                }
            }
            self.updateTrashSize()
        }
    }

    public func addToRecents(_ url: URL) {
        let std = url.standardizedFileURL
        if std == Self.recentsVirtualURL || std.scheme == "wiles" { return }
        var current = recentOpenedURLs.filter { $0.standardizedFileURL != std }
        current.insert(std, at: 0)
        if current.count > 50 {
            current = Array(current.prefix(50))
        }
        self.recentOpenedURLs = current
    }
}
