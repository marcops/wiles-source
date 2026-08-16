import GitBeacon
import Observation
import SwiftUI

@Observable
@MainActor
public final class AppState: @unchecked Sendable {
    // MARK: - Domain Stores

    public var navigation: NavigationStore
    public var preferences: PreferencesStore
    public var modal: ModalStore
    public var selection: SelectionStore
    public var fileSystem: FileSystemStore
    public var smartFolder: SmartFolderStore

    func startDirectoryMonitoring(for url: URL) {
        fileSystem.startDirectoryMonitoring(for: url) { [weak self] in
            Task { @MainActor in
                self?.refreshCurrentDirectory(isUserInitiated: false)
            }
        }
    }

    public func showError(_ message: String) {
        modal.showError(message)
    }

    /// Prefer this over `showError(error.localizedDescription)` for errors that can come from
    /// `FileSystemService` operations: known `WilesError` cases get a real localized message via
    /// `appState.tr(...)` instead of surfacing an unlocalized system/English string.
    public func showError(_ error: Error) {
        if case .itemAlreadyInDestination = error as? WilesError {
            showError(tr(.itemAlreadyInDestination))
        } else {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Operational State

    public var smartFolders: [SmartFolder] = SmartFolderService.loadSavedSmartFolders()

    public func addSmartFolder(_ folder: SmartFolder) {
        smartFolders.append(folder)
        do {
            try SmartFolderService.saveSmartFolders(smartFolders)
        } catch {
            ErrorReporter.report(error, context: "Adding smart folder")
            showError(error.localizedDescription)
        }
    }

    public func removeSmartFolder(_ folder: SmartFolder) {
        smartFolders.removeAll { $0.id == folder.id }
        do {
            try SmartFolderService.saveSmartFolders(smartFolders)
        } catch {
            ErrorReporter.report(error, context: "Removing smart folder")
            showError(error.localizedDescription)
        }
    }

    public static let recentsVirtualURL = URL(fileURLWithPath: "/virtual/recents")

    public var searchQuery: String = "" {
        didSet {
            guard !smartFolder.suppressSearchQueryRefresh else { return }
            // A normal searchQuery edit (typing, clearing, a kind:/date: filter button, a tag
            // click) must unblock refreshCurrentDirectory() below — otherwise it stays stuck behind
            // the guard meant only for the leftover FSEvents watcher on whatever folder was open
            // before the smart folder ran. `activeFolderID` deliberately stays put: it only drives
            // the sidebar's active-row highlight, which should keep showing the smart folder as
            // selected while its results are on screen, even as the query text is refined — only a
            // real navigation (navigateTo) should move that highlight elsewhere.
            smartFolder.isActive = false
            refreshCurrentDirectory()
        }
    }

    /// Sets `searchQuery` without necessarily reloading the current folder — a smart folder run
    /// populates `fileSystem.items` from its own cross-directory query and must not race against a
    /// normal single-directory reload of whatever folder happens to be open, which used to silently
    /// overwrite the smart folder's results (and the selection) shortly after they appeared.
    func setSearchQuery(_ query: String, triggerRefresh: Bool) {
        guard !triggerRefresh else {
            searchQuery = query
            return
        }
        smartFolder.suppressSearchQueryRefresh = true
        searchQuery = query
        smartFolder.suppressSearchQueryRefresh = false
    }

    public var isSearching: Bool = false

    /// In-flight directory load spawned by `refreshCurrentDirectory()`. Cancelled and replaced on every
    /// call so rapid search keystrokes or navigations can't leave multiple concurrent loads racing to
    /// apply stale results.
    var refreshTask: Task<Void, Never>?
    /// In-flight `~/.Trash` enumeration spawned by `updateTrashSize()`. Cancelled and replaced on every
    /// call so it never piles up multiple concurrent full-Trash walks.
    private var trashSizeTask: Task<Void, Never>?
    /// Timestamp of the last trash-size enumeration triggered opportunistically from
    /// `refreshCurrentDirectory()`, used to coalesce it to a coarse interval instead of firing on
    /// every navigation/search keystroke/FSEvents refresh.
    var lastOpportunisticTrashSizeCheck: Date = .distantPast
    static let trashSizeCheckInterval: TimeInterval = 30

    public var selectedURLs: Set<URL> = []
    public var clipboard: ClipboardState?
    public var navigationMode: NavigationMode = .gnome {
        didSet { UserDefaults.standard.set(navigationMode.rawValue, forKey: DefaultsKey.navigationMode.rawValue) }
    }

    public var trashSizeString: String = ""
    public var isTrashUpdating: Bool = false

    public var isCompactMode: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.isCompactMode.rawValue) {
        didSet { UserDefaults.standard.set(isCompactMode, forKey: DefaultsKey.isCompactMode.rawValue) }
    }

    public var listColumnStates: [ListColumnState] = ListColumnState.defaults() {
        didSet {
            guard !suppressColumnStatePersistence else { return }
            saveListColumnStates()
        }
    }

    /// Set while a column-resize drag is in progress so intermediate width updates (which fire on every
    /// mouse-move delta) don't each trigger a synchronous JSON encode + `UserDefaults` write. The final
    /// width is persisted once via `persistColumnWidths()` on drag end. See `ColumnResizeHandle`.
    var suppressColumnStatePersistence: Bool = false

    public var perFolderViewModes: [String: String] = (
        UserDefaults.standard.dictionary(forKey: DefaultsKey.perFolderViewModes.rawValue) as? [String: String]) ??
        [:] {
        didSet { UserDefaults.standard.set(perFolderViewModes, forKey: DefaultsKey.perFolderViewModes.rawValue) }
    }

    public init() {
        navigation = NavigationStore()
        preferences = PreferencesStore()
        modal = ModalStore()
        selection = SelectionStore()
        fileSystem = FileSystemStore()
        smartFolder = SmartFolderStore()

        updateTrashSize()
    }

    public func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: preferences.appLanguage)
    }

    public var statusText: String {
        let totalCount = fileSystem.items.count
        let selCount = selectedURLs.count

        if selCount == 0 {
            let totalFilesSize = fileSystem.items.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
            if totalFilesSize > 0 {
                let formattedSize = ByteCountFormatter.string(fromByteCount: totalFilesSize, countStyle: .file)
                return "\(totalCount) \(totalCount == 1 ? "item" : "itens") (\(formattedSize))"
            }
            return "\(totalCount) \(totalCount == 1 ? "item" : "itens")"
        } else {
            let selItems = fileSystem.items.filter { selectedURLs.contains($0.url) }
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
    public func loadFreeSpaceText() async -> String? {
        let url = navigation.currentURL
        let capacity = await Task.detached(priority: .utility) { () -> Int? in
            (try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]))?.volumeAvailableCapacity
        }.value
        guard let capacity else { return nil }
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(capacity), countStyle: .file)
        return "\(formatted) \(tr(.freeSpace))"
    }

    public func addFavorite(_ url: URL) {
        let std = url.standardizedFileURL
        if !preferences.favoriteURLs.contains(where: { $0.standardizedFileURL == std }) {
            preferences.favoriteURLs.append(std)
        }
    }

    public func removeFavorite(_ url: URL) {
        let std = url.standardizedFileURL
        preferences.favoriteURLs.removeAll { $0.standardizedFileURL == std }
    }

    public func isFavorite(_ url: URL) -> Bool {
        let std = url.standardizedFileURL
        return preferences.favoriteURLs.contains(where: { $0.standardizedFileURL == std })
    }

    /// Single entry point for every in-app move (cut/paste, drag onto a folder row, breadcrumb
    /// drop, sidebar-favorite drop) — moves the item on disk, then keeps favorites in sync. Every
    /// call site should go through this, not call `FileSystemService.moveItem` directly, so a
    /// second in-app move location can never again forget to re-sync favorites (see
    /// `remapFavorites` below for why it must be called after every move).
    @discardableResult
    public func moveItem(at url: URL, toFolder targetFolder: URL) throws -> URL {
        let destURL = try FileSystemService.moveItem(at: url, toFolder: targetFolder)
        remapFavorites(from: url, to: destURL)
        return destURL
    }

    /// Favorites are stored as plain paths (`PreferencesStore.favoriteURLs`), not macOS bookmark
    /// data, so a favorited folder moved outside the app (Finder, another app) has no way to be
    /// re-found — that's a real capability gap, not a bug. But a move performed *inside* Wiles
    /// already gives us both the old and new URL in the same call, so there's no excuse for a
    /// favorite silently going stale in that case. Called by `moveItem(at:toFolder:)` above for
    /// every single-item in-app move; `AppState+Operations.executePaste` calls it directly too,
    /// since its bulk-move loop must keep the actual disk move off `@MainActor` (rule 29.16) and
    /// can only hop back to `@MainActor` for this lightweight favorites sync, not the whole
    /// `moveItem(at:toFolder:)` wrapper. Not `public` — not meant as a general entry point outside
    /// AppState's own move paths. Handles both the favorited item itself moving and a favorited
    /// item nested inside a moved ancestor folder.
    func remapFavorites(from oldURL: URL, to newURL: URL) {
        let oldStd = oldURL.standardizedFileURL
        let newStd = newURL.standardizedFileURL
        for (index, favorite) in preferences.favoriteURLs.enumerated() {
            let favStd = favorite.standardizedFileURL
            if favStd == oldStd {
                preferences.favoriteURLs[index] = newStd
            } else if favStd.path.hasPrefix(oldStd.path + "/") {
                let relativePath = String(favStd.path.dropFirst(oldStd.path.count))
                preferences.favoriteURLs[index] = URL(fileURLWithPath: newStd.path + relativePath)
            }
        }
    }

    public func moveSelectedFavorite(offset: Int, windowUIState: WindowUIState) {
        guard let selected = windowUIState.selectedFavoriteURL?.standardizedFileURL,
              selected == navigation.currentURL.standardizedFileURL,
              let index = preferences.favoriteURLs.firstIndex(where: { $0.standardizedFileURL == selected }) else { return }
        let newIndex = index + offset
        guard preferences.favoriteURLs.indices.contains(newIndex) else { return }
        preferences.favoriteURLs.swapAt(index, newIndex)
    }

    public func compressSelectedToZIP() {
        let urls = Array(selectedURLs)
        guard !urls.isEmpty else { return }
        let current = navigation.currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileSystemService.compressToZIP(urls: urls, in: current)
            } catch {
                ErrorReporter.report(error, context: "Compressing items to ZIP")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }

    public func compressSelectedToZIPWithPassword(_ password: String, urls: [URL]?) {
        guard let urls, !urls.isEmpty else { return }
        let current = navigation.currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try ArchiveService.compressToZIP(urls: urls, in: current, password: password)
            } catch {
                ErrorReporter.report(error, context: "Compressing items to password-protected ZIP")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }

    public func extractArchive(url: URL) {
        let current = navigation.currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileSystemService.extractZIP(archiveURL: url, to: current)
            } catch {
                ErrorReporter.report(error, context: "Extracting archive")
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }

    private enum TrashSizeResult {
        case success(Int64)
        case noTrash
        case cancelled
    }

    /// `nonisolated` on purpose: runs inside `Task.detached`, off the main actor, so the
    /// potentially-large `~/.Trash` enumeration below never blocks the UI.
    private nonisolated static func computeTrashSize() -> TrashSizeResult {
        guard let url = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first else {
            return .noTrash
        }
        var totalSize: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return .noTrash
        }
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled {
                return .cancelled
            }
            if let res = try? fileURL.resourceValues(forKeys: Set(keys)), res.isDirectory == false, let size = res.fileSize {
                totalSize += Int64(size)
            }
        }
        guard !Task.isCancelled else { return .cancelled }
        return .success(totalSize)
    }

    public func updateTrashSize() {
        // Supersede any enumeration already in flight instead of piling another one on top of it —
        // this fires on every navigation/search keystroke via refreshCurrentDirectory().
        trashSizeTask?.cancel()
        isTrashUpdating = true
        trashSizeTask = Task.detached(priority: .background) { [weak self] in
            switch Self.computeTrashSize() {
            case let .success(totalSize):
                let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                await MainActor.run { [weak self] in
                    self?.trashSizeString = sizeStr
                    self?.isTrashUpdating = false
                }
            case .noTrash:
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
            case .cancelled:
                break
            }
        }
    }

    public func performEmptyTrash() {
        Task { @MainActor in
            self.isTrashUpdating = true
        }
        Task.detached(priority: .userInitiated) {
            let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            guard let url = trashURL else {
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
                return
            }
            let fm = FileManager.default
            guard let paths = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
                return
            }
            let failedCount = Self.removeTrashContents(paths, using: fm)
            await MainActor.run { [weak self] in
                self?.updateTrashSize()
                self?.refreshCurrentDirectory()
                if failedCount > 0 {
                    self?.showError("Failed to permanently delete \(failedCount) item(s) from Trash.")
                }
            }
        }
    }

    private nonisolated static func removeTrashContents(_ paths: [URL], using fm: FileManager) -> Int {
        var failedCount = 0
        for path in paths {
            do {
                try fm.removeItem(at: path)
            } catch {
                ErrorReporter.report(error, context: "Emptying Trash")
                failedCount += 1
            }
        }
        return failedCount
    }
}
