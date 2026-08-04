import SwiftUI
import Observation

public enum SearchScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case name
    case content

    public var id: String { rawValue }
}

@Observable
@MainActor
public final class AppState {
    public var currentURL: URL {
        didSet {
            pathText = currentURL.path
            UserDefaults.standard.set(currentURL.path, forKey: DefaultsKey.lastOpenedFolder.rawValue)
        }
    }

    public var historyBack: [URL] = []
    public var historyForward: [URL] = []
    public var items: [FileItem] = []
    public var isLoading: Bool = false
    /// Bumped by the right-arrow key handler so Column View can drill into the selected item's column, same as a click.
    public var columnViewDrillRightTrigger: Int = 0
    /// Set alongside `columnViewVerticalTrigger` so Column View moves selection within its own active column instead of the root `items` list.
    public var columnViewVerticalDirection: Int = 0
    public var columnViewVerticalTrigger: Int = 0
    /// Bumped by the left-arrow key handler so Column View shifts focus back one column instead of resetting via `goUp()`.
    public var columnViewMoveLeftTrigger: Int = 0
    /// Cell frames from the Grid View, updated live. Used to compute the real column count.
    public var gridCellFrames: [URL: CGRect] = [:]
    private let directoryMonitor = DirectoryMonitor()

    func startDirectoryMonitoring(for url: URL) {
        guard url.isFileURL else { return }
        directoryMonitor.start(path: url.path) { [weak self] in
            Task { @MainActor in
                self?.refreshCurrentDirectory()
            }
        }
    }

    /// Actual number of columns currently rendered in Grid View — derived from real cell Y positions.
    public var gridColumnCount: Int {
        guard gridCellFrames.count > 1 else { return 1 }
        let ys = gridCellFrames.values.map { $0.origin.y }
        guard let firstY = ys.min() else { return 1 }
        return ys.filter { abs($0 - firstY) < 5 }.count
    }

    public var viewMode: ViewMode = .grid {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: DefaultsKey.viewMode.rawValue) }
    }
    public var appAppearance: AppAppearance = .system {
        didSet { UserDefaults.standard.set(appAppearance.rawValue, forKey: DefaultsKey.appAppearance.rawValue) }
    }
    public var sidebarMode: SidebarMode = .places {
        didSet { UserDefaults.standard.set(sidebarMode.rawValue, forKey: DefaultsKey.sidebarMode.rawValue) }
    }
    public var sidebarWidth = Double(LayoutTokens.sidebarIdealWidth) {
        didSet { UserDefaults.standard.set(sidebarWidth, forKey: DefaultsKey.sidebarWidth.rawValue) }
    }
    public var sortOption: SortOption = .name {
        didSet { UserDefaults.standard.set(sortOption.rawValue, forKey: DefaultsKey.sortOption.rawValue) }
    }
    public var sortAscending: Bool = true {
        didSet { UserDefaults.standard.set(sortAscending, forKey: DefaultsKey.sortAscending.rawValue) }
    }
    public var showHiddenFiles: Bool = false {
        didSet { UserDefaults.standard.set(showHiddenFiles, forKey: DefaultsKey.showHiddenFiles.rawValue) }
    }
    public var showFavorites: Bool = true {
        didSet { UserDefaults.standard.set(showFavorites, forKey: DefaultsKey.showFavorites.rawValue) }
    }
    public var showRecents: Bool = true {
        didSet { UserDefaults.standard.set(showRecents, forKey: DefaultsKey.showRecents.rawValue) }
    }
    public var showPlaces: Bool = true {
        didSet { UserDefaults.standard.set(showPlaces, forKey: DefaultsKey.showPlaces.rawValue) }
    }
    public var showNetworkAndCloud: Bool = false {
        didSet { UserDefaults.standard.set(showNetworkAndCloud, forKey: DefaultsKey.showNetworkAndCloud.rawValue) }
    }
    public var showSidebarSectionTitles: Bool = true {
        didSet { UserDefaults.standard.set(showSidebarSectionTitles, forKey: DefaultsKey.showSidebarSectionTitles.rawValue) }
    }
    public var appLanguage: AppLanguage = .system {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: DefaultsKey.appLanguage.rawValue) }
    }
    public var isFavoritesExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isFavoritesExpanded, forKey: DefaultsKey.isFavoritesExpanded.rawValue) }
    }
    public var isMacExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isMacExpanded, forKey: DefaultsKey.isMacExpanded.rawValue) }
    }
    public var isNetworkExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isNetworkExpanded, forKey: DefaultsKey.isNetworkExpanded.rawValue) }
    }
    public var isRecentsExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isRecentsExpanded, forKey: DefaultsKey.isRecentsExpanded.rawValue) }
    }
    public var isDevicesExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isDevicesExpanded, forKey: DefaultsKey.isDevicesExpanded.rawValue) }
    }
    public var isTreeExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isTreeExpanded, forKey: DefaultsKey.isTreeExpanded.rawValue) }
    }
    public var expandedTreePaths: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(expandedTreePaths), forKey: DefaultsKey.expandedTreePaths.rawValue) }
    }
    public var isTagsExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isTagsExpanded, forKey: DefaultsKey.isTagsExpanded.rawValue) }
    }
    public var isSmartFoldersExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isSmartFoldersExpanded, forKey: DefaultsKey.isSmartFoldersExpanded.rawValue) }
    }
    public var searchScope: SearchScope = .name {
        didSet { UserDefaults.standard.set(searchScope.rawValue, forKey: DefaultsKey.searchScope.rawValue) }
    }
    public var smartFolders: [SmartFolder] = SmartFolderService.loadSavedSmartFolders()
    public var showSaveSmartFolderSheet: Bool = false
    public var showPasswordCompressSheet: Bool = false
    public var passwordCompressURLs: [URL]?
    public var inspectArchiveURL: URL?
    public var showArchiveInspectionSheet: Bool = false
    public var errorMessage: String?
    public var showErrorAlert: Bool = false

    public func showError(_ message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
    }

    public func addSmartFolder(_ folder: SmartFolder) {
        smartFolders.append(folder)
        SmartFolderService.saveSmartFolders(smartFolders)
    }

    public func removeSmartFolder(_ folder: SmartFolder) {
        smartFolders.removeAll { $0.id == folder.id }
        SmartFolderService.saveSmartFolders(smartFolders)
    }
    public static let recentsVirtualURL = URL(fileURLWithPath: "/virtual/recents")
    public var recentOpenedURLs: [URL] = [] {
        didSet {
            let paths = recentOpenedURLs.map { $0.path }
            UserDefaults.standard.set(paths, forKey: DefaultsKey.recentOpenedURLs.rawValue)
        }
    }
    public var showTags: Bool = false {
        didSet {
            UserDefaults.standard.set(showTags, forKey: DefaultsKey.showTags.rawValue)
            refreshCurrentDirectory()
        }
    }
    public var showFooter: Bool = true {
        didSet { UserDefaults.standard.set(showFooter, forKey: DefaultsKey.showFooter.rawValue) }
    }
    public var showTerminalDrawer: Bool = false {
        didSet { UserDefaults.standard.set(showTerminalDrawer, forKey: DefaultsKey.showTerminalDrawer.rawValue) }
    }
    public var showPreviewSidebar: Bool = false {
        didSet { UserDefaults.standard.set(showPreviewSidebar, forKey: DefaultsKey.showPreviewSidebar.rawValue) }
    }
    public var sidebarTranslucentLevel: Int = 80 {
        didSet { UserDefaults.standard.set(sidebarTranslucentLevel, forKey: DefaultsKey.sidebarTranslucentLevel.rawValue) }
    }
    public var contentTranslucentLevel: Int = 40 {
        didSet { UserDefaults.standard.set(contentTranslucentLevel, forKey: DefaultsKey.contentTranslucentLevel.rawValue) }
    }
    public var translucentLevel: Int {
        get { sidebarTranslucentLevel }
        set {
            sidebarTranslucentLevel = newValue
            contentTranslucentLevel = newValue
        }
    }
    /// Single source of truth for translucency math — every translucent surface in the app
    /// (sidebar, content, footer controls, etc.) reads its opacity from here.
    public var sidebarOverlayOpacity: Double {
        let base = 1.0 - Double(sidebarTranslucentLevel) / 100.0
        return appAppearance == .light ? base * 0.5 : base
    }
    public var contentOverlayOpacity: Double {
        let base = 1.0 - Double(contentTranslucentLevel) / 100.0
        return appAppearance == .light ? base * 0.5 : base
    }
    public var iconSize: Double = 54.0 {
        didSet { UserDefaults.standard.set(iconSize, forKey: DefaultsKey.iconSize.rawValue) }
    }
    public var favoriteURLs: [URL] = [] {
        didSet {
            let paths = favoriteURLs.map { $0.path }
            UserDefaults.standard.set(paths, forKey: DefaultsKey.favoriteURLs.rawValue)
        }
    }
    public var showHelpSheet: Bool = false
    public var showAboutSheet: Bool = false

    public var isEditingPath: Bool = false
    public var pathText: String = ""
    public var searchQuery: String = "" {
        didSet {
            refreshCurrentDirectory()
        }
    }
    public var isSearching: Bool = false

    public var selectedURLs: Set<URL> = []
    public var quickLookURL: URL?
    public var clipboard: ClipboardState?
    public var navigationMode: NavigationMode = .gnome {
        didSet { UserDefaults.standard.set(navigationMode.rawValue, forKey: DefaultsKey.navigationMode.rawValue) }
    }

    public var propertiesItem: FileItem?
    public var renameItem: FileItem?
    public var imageConverterItem: FileItem?
    public var symlinkItem: FileItem?
    public var showBatchRenameSheet: Bool = false
    public var showDiskUsageSheet: Bool = false
    public var showNewFolderSheet: Bool = false
    public var showNewFileSheet: Bool = false
    public var trashSizeString: String = ""
    public var showEmptyTrashAlert: Bool = false
    public var showShortcutsHUD: Bool = false
    public var isTrashUpdating: Bool = false
    public var showConnectToServerSheet: Bool = false
    public var showAutoOrganizationSheet: Bool = false
    public var showHttpShareSheet: Bool = false
    public var httpShareFolderURL: URL?

    public var isCompactMode: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.isCompactMode.rawValue) {
        didSet { UserDefaults.standard.set(isCompactMode, forKey: DefaultsKey.isCompactMode.rawValue) }
    }

    public var listColumnStates: [ListColumnState] = ListColumnState.defaults() {
        didSet { saveListColumnStates() }
    }

    public var perFolderViewModes: [String: String] = (UserDefaults.standard.dictionary(forKey: DefaultsKey.perFolderViewModes.rawValue) as? [String: String]) ?? [:] {
        didSet { UserDefaults.standard.set(perFolderViewModes, forKey: DefaultsKey.perFolderViewModes.rawValue) }
    }

    public init() {
        let defaults = UserDefaults.standard
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let lastFolder = defaults.string(forKey: DefaultsKey.lastOpenedFolder.rawValue),
           FileManager.default.fileExists(atPath: lastFolder) {
            let lastURL = URL(fileURLWithPath: lastFolder)
            self.currentURL = lastURL
            self.pathText = lastURL.path
        } else {
            self.currentURL = home
            self.pathText = home.path
        }
        restoreLayoutPreferences(defaults)
        restoreSidebarPreferences(defaults, home: home)
        restoreDisplayPreferences(defaults)
        restoreContentPreferences(defaults, home: home)
        self.updateTrashSize()
    }

    public func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: appLanguage)
    }

    public var statusText: String {
        let totalCount = items.count
        let selCount = selectedURLs.count

        if selCount == 0 {
            let totalFilesSize = items.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
            if totalFilesSize > 0 {
                let formattedSize = ByteCountFormatter.string(fromByteCount: totalFilesSize, countStyle: .file)
                return "\(totalCount) \(totalCount == 1 ? "item" : "itens") (\(formattedSize))"
            }
            return "\(totalCount) \(totalCount == 1 ? "item" : "itens")"
        } else {
            let selItems = items.filter { selectedURLs.contains($0.url) }
            let selFilesSize = selItems.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
            if selFilesSize > 0 {
                let formattedSize = ByteCountFormatter.string(fromByteCount: selFilesSize, countStyle: .file)
                return "\(selCount) / \(totalCount) (\(formattedSize))"
            } else {
                return "\(selCount) / \(totalCount)"
            }
        }
    }

    public var freeSpaceText: String? {
        if let values = try? currentURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let capacity = values.volumeAvailableCapacity {
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(capacity), countStyle: .file)
            return "\(formatted) \(tr(.freeSpace))"
        }
        return nil
    }

    public func addFavorite(_ url: URL) {
        let std = url.standardizedFileURL
        if !favoriteURLs.contains(where: { $0.standardizedFileURL == std }) {
            favoriteURLs.append(std)
        }
    }

    public func removeFavorite(_ url: URL) {
        let std = url.standardizedFileURL
        favoriteURLs.removeAll { $0.standardizedFileURL == std }
    }

    public func isFavorite(_ url: URL) -> Bool {
        let std = url.standardizedFileURL
        return favoriteURLs.contains(where: { $0.standardizedFileURL == std })
    }

    public func compressSelectedToZIP() {
        let urls = Array(selectedURLs)
        guard !urls.isEmpty else { return }
        let current = currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileSystemService.compressToZIP(urls: urls, in: current)
            } catch {
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
        let current = currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileSystemService.extractZIP(archiveURL: url, to: current)
            } catch {
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }

    public func updateTrashSize() {
        Task { @MainActor in
            self.isTrashUpdating = true
        }
        Task.detached(priority: .background) {
            let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            guard let url = trashURL else {
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
                return
            }
            var totalSize: Int64 = 0
            let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
                return
            }
            while let fileURL = enumerator.nextObject() as? URL {
                if let res = try? fileURL.resourceValues(forKeys: Set(keys)) {
                    if res.isDirectory == false, let size = res.fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
            let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            await MainActor.run { [weak self] in
                self?.trashSizeString = sizeStr
                self?.isTrashUpdating = false
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
            for path in paths {
                try? fm.removeItem(at: path)
            }
            await MainActor.run { [weak self] in
                self?.updateTrashSize()
                self?.refreshCurrentDirectory()
            }
        }
    }
}
