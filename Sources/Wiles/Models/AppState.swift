import SwiftUI
import Observation

@Observable
@MainActor
public final class AppState {
    public var currentURL: URL {
        didSet { pathText = currentURL.path }
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
    /// Actual number of columns currently rendered in Grid View — derived from real cell Y positions.
    public var gridColumnCount: Int {
        guard gridCellFrames.count > 1 else { return 1 }
        let ys = gridCellFrames.values.map { $0.origin.y }
        guard let firstY = ys.min() else { return 1 }
        return ys.filter { abs($0 - firstY) < 5 }.count
    }
    
    public var viewMode: ViewMode = .grid {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "wiles_viewMode") }
    }
    public var appAppearance: AppAppearance = .system {
        didSet { UserDefaults.standard.set(appAppearance.rawValue, forKey: "wiles_appAppearance") }
    }
    public var sidebarMode: SidebarMode = .places {
        didSet { UserDefaults.standard.set(sidebarMode.rawValue, forKey: "wiles_sidebarMode") }
    }
    public var sidebarWidth: Double = Double(LayoutTokens.sidebarIdealWidth) {
        didSet { UserDefaults.standard.set(sidebarWidth, forKey: "wiles_sidebarWidth") }
    }
    public var sortOption: SortOption = .name {
        didSet { UserDefaults.standard.set(sortOption.rawValue, forKey: "wiles_sortOption") }
    }
    public var sortAscending: Bool = true {
        didSet { UserDefaults.standard.set(sortAscending, forKey: "wiles_sortAscending") }
    }
    public var showHiddenFiles: Bool = false {
        didSet { UserDefaults.standard.set(showHiddenFiles, forKey: "wiles_showHiddenFiles") }
    }
    public var showFavorites: Bool = true {
        didSet { UserDefaults.standard.set(showFavorites, forKey: "wiles_showFavorites") }
    }
    public var showRecents: Bool = true {
        didSet { UserDefaults.standard.set(showRecents, forKey: "wiles_showRecents") }
    }
    public var showMacSection: Bool = false {
        didSet { UserDefaults.standard.set(showMacSection, forKey: "wiles_showMacSection") }
    }
    public var showNetworkAndCloud: Bool = false {
        didSet { UserDefaults.standard.set(showNetworkAndCloud, forKey: "wiles_showNetworkAndCloud") }
    }
    public var appLanguage: AppLanguage = .system {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: "wiles_appLanguage") }
    }
    public var isFavoritesExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isFavoritesExpanded, forKey: "wiles_isFavoritesExpanded") }
    }
    public var isMacExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isMacExpanded, forKey: "wiles_isMacExpanded") }
    }
    public var isNetworkExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isNetworkExpanded, forKey: "wiles_isNetworkExpanded") }
    }
    public var isRecentsExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isRecentsExpanded, forKey: "wiles_isRecentsExpanded") }
    }
    public var isDevicesExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isDevicesExpanded, forKey: "wiles_isDevicesExpanded") }
    }
    public var isTreeExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isTreeExpanded, forKey: "wiles_isTreeExpanded") }
    }
    public var expandedTreePaths: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(expandedTreePaths), forKey: "wiles_expandedTreePaths") }
    }
    public var isTagsExpanded: Bool = true {
        didSet { UserDefaults.standard.set(isTagsExpanded, forKey: "wiles_isTagsExpanded") }
    }
    public static let recentsVirtualURL = URL(fileURLWithPath: "/virtual/recents")
    public var recentOpenedURLs: [URL] = [] {
        didSet {
            let paths = recentOpenedURLs.map { $0.path }
            UserDefaults.standard.set(paths, forKey: "wiles_recentOpenedURLs")
        }
    }
    public var showTags: Bool = false {
        didSet {
            UserDefaults.standard.set(showTags, forKey: "wiles_showTags")
            refreshCurrentDirectory()
        }
    }
    public var showFooter: Bool = true {
        didSet { UserDefaults.standard.set(showFooter, forKey: "wiles_showFooter") }
    }
    public var showTerminalDrawer: Bool = false {
        didSet { UserDefaults.standard.set(showTerminalDrawer, forKey: "wiles_showTerminalDrawer") }
    }
    public var showPreviewSidebar: Bool = false {
        didSet { UserDefaults.standard.set(showPreviewSidebar, forKey: "wiles_showPreviewSidebar") }
    }
    public var sidebarTranslucentLevel: Int = 80 {
        didSet { UserDefaults.standard.set(sidebarTranslucentLevel, forKey: "wiles_sidebarTranslucentLevel") }
    }
    public var contentTranslucentLevel: Int = 40 {
        didSet { UserDefaults.standard.set(contentTranslucentLevel, forKey: "wiles_contentTranslucentLevel") }
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
        didSet { UserDefaults.standard.set(iconSize, forKey: "wiles_iconSize") }
    }
    public var favoriteURLs: [URL] = [] {
        didSet {
            let paths = favoriteURLs.map { $0.path }
            UserDefaults.standard.set(paths, forKey: "wiles_favoriteURLs")
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
    public var quickLookURL: URL? = nil
    public var clipboard: ClipboardState? = nil
    public var navigationMode: NavigationMode = .gnome {
        didSet { UserDefaults.standard.set(navigationMode.rawValue, forKey: "wiles_navigationMode") }
    }
    
    public var propertiesItem: FileItem? = nil
    public var renameItem: FileItem? = nil
    public var imageConverterItem: FileItem? = nil
    public var symlinkItem: FileItem? = nil
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
    public var httpShareFolderURL: URL? = nil
    
    public var isCompactMode: Bool = UserDefaults.standard.bool(forKey: "wiles_isCompactMode") {
        didSet { UserDefaults.standard.set(isCompactMode, forKey: "wiles_isCompactMode") }
    }

    public var listColumnStates: [ListColumnState] = ListColumnState.defaults() {
        didSet { saveListColumnStates() }
    }

    private func saveListColumnStates() {
        if let data = try? JSONEncoder().encode(listColumnStates) {
            UserDefaults.standard.set(data, forKey: "wiles_listColumnStates")
        }
    }

    public func columnWidth(for column: ListColumn) -> CGFloat {
        listColumnStates.first { $0.column == column }?.width ?? column.defaultWidth
    }

    public func isColumnVisible(_ column: ListColumn) -> Bool {
        listColumnStates.first { $0.column == column }?.isVisible ?? true
    }

    public func setColumnWidth(_ column: ListColumn, width: CGFloat) {
        guard let idx = listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        listColumnStates[idx].width = max(LayoutTokens.columnMinWidth, width)
    }

    public func autoFitColumnWidth(_ column: ListColumn) {
        let newWidth = ColumnAutoFitService.calculateAutoFitWidth(for: column, in: self)
        setColumnWidth(column, width: newWidth)
    }

    public func toggleColumnVisibility(_ column: ListColumn) {
        guard !column.isAlwaysVisible,
              let idx = listColumnStates.firstIndex(where: { $0.column == column }) else { return }
        listColumnStates[idx].isVisible.toggle()
    }
    
    public var perFolderViewModes: [String: String] = (UserDefaults.standard.dictionary(forKey: "wiles_perFolderViewModes") as? [String: String]) ?? [:] {
        didSet { UserDefaults.standard.set(perFolderViewModes, forKey: "wiles_perFolderViewModes") }
    }
    
    public func viewModeForFolder(_ url: URL) -> ViewMode {
        if let raw = perFolderViewModes[url.standardizedFileURL.path], let mode = ViewMode(rawValue: raw) {
            return mode
        }
        return viewMode
    }
    
    public func setViewModeForFolder(_ mode: ViewMode, for url: URL) {
        perFolderViewModes[url.standardizedFileURL.path] = mode.rawValue
        self.viewMode = mode
    }
    
    public func performImageConversion(
        item: FileItem,
        targetFormat: ImageFormat,
        preset: ResizePreset,
        cropPreset: CropPreset,
        quality: Double
    ) {
        Task.detached(priority: .userInitiated) {
            do {
                let newURL = try ImageConverterService.convertImage(
                    at: item.url,
                    targetFormat: targetFormat,
                    preset: preset,
                    cropPreset: cropPreset,
                    quality: quality
                )
                await MainActor.run {
                    self.refreshCurrentDirectory()
                    self.selectedURLs = [newURL]
                }
            } catch {
                print("Error converting image \(item.url.path): \(error)")
            }
        }
    }
    
    public func performRename(item: FileItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        do {
            let newURL = try FileSystemService.renameItem(at: item.url, newName: trimmed)
            UndoRedoService.shared.recordAction(.rename(oldURL: item.url, newURL: newURL))
            self.refreshCurrentDirectory()
            self.selectedURLs = [newURL]
        } catch {
            print("Error renaming item \(item.url.path): \(error)")
        }
    }
    
    public func performBatchRename(items: [FileItem], mode: BatchRenameMode) {
        do {
            let newURLs = try BatchRenameService.performBatchRename(items: items, mode: mode)
            self.refreshCurrentDirectory()
            self.selectedURLs = Set(newURLs)
        } catch {
            print("Error in batch rename: \(error)")
        }
    }
    
    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.currentURL = home
        self.pathText = home.path
        
        let defaults = UserDefaults.standard
        if let modeStr = defaults.string(forKey: "wiles_sidebarMode"), let mode = SidebarMode(rawValue: modeStr) {
            self.sidebarMode = mode
        }
        if defaults.object(forKey: "wiles_sidebarWidth") != nil {
            let savedWidth = defaults.double(forKey: "wiles_sidebarWidth")
            self.sidebarWidth = min(Double(LayoutTokens.sidebarMaxWidth), max(Double(LayoutTokens.sidebarMinWidth), savedWidth))
        }
        if let navStr = defaults.string(forKey: "wiles_navigationMode"), let mode = NavigationMode(rawValue: navStr) {
            self.navigationMode = mode
        }
        if let viewStr = defaults.string(forKey: "wiles_viewMode"), let mode = ViewMode(rawValue: viewStr) {
            self.viewMode = mode
        }
        if let appearanceStr = defaults.string(forKey: "wiles_appAppearance"), let appearance = AppAppearance(rawValue: appearanceStr) {
            self.appAppearance = appearance
        }
        if let sortStr = defaults.string(forKey: "wiles_sortOption"), let opt = SortOption(rawValue: sortStr) {
            self.sortOption = opt
        }
        if defaults.object(forKey: "wiles_sortAscending") != nil {
            self.sortAscending = defaults.bool(forKey: "wiles_sortAscending")
        }
        if defaults.object(forKey: "wiles_showHiddenFiles") != nil {
            self.showHiddenFiles = defaults.bool(forKey: "wiles_showHiddenFiles")
        }
        if defaults.object(forKey: "wiles_showFavorites") != nil {
            self.showFavorites = defaults.bool(forKey: "wiles_showFavorites")
        }
        if defaults.object(forKey: "wiles_showRecents") != nil {
            self.showRecents = defaults.bool(forKey: "wiles_showRecents")
        }
        if defaults.object(forKey: "wiles_showMacSection") != nil {
            self.showMacSection = defaults.bool(forKey: "wiles_showMacSection")
        }
        if defaults.object(forKey: "wiles_showNetworkAndCloud") != nil {
            self.showNetworkAndCloud = defaults.bool(forKey: "wiles_showNetworkAndCloud")
        }
        if let langStr = defaults.string(forKey: "wiles_appLanguage"), let lang = AppLanguage(rawValue: langStr) {
            self.appLanguage = lang
        }
        if defaults.object(forKey: "wiles_isFavoritesExpanded") != nil {
            self.isFavoritesExpanded = defaults.bool(forKey: "wiles_isFavoritesExpanded")
        }
        if defaults.object(forKey: "wiles_isMacExpanded") != nil {
            self.isMacExpanded = defaults.bool(forKey: "wiles_isMacExpanded")
        }
        if defaults.object(forKey: "wiles_isNetworkExpanded") != nil {
            self.isNetworkExpanded = defaults.bool(forKey: "wiles_isNetworkExpanded")
        }
        if defaults.object(forKey: "wiles_isRecentsExpanded") != nil {
            self.isRecentsExpanded = defaults.bool(forKey: "wiles_isRecentsExpanded")
        }
        if defaults.object(forKey: "wiles_isDevicesExpanded") != nil {
            self.isDevicesExpanded = defaults.bool(forKey: "wiles_isDevicesExpanded")
        }
        if defaults.object(forKey: "wiles_isTreeExpanded") != nil {
            self.isTreeExpanded = defaults.bool(forKey: "wiles_isTreeExpanded")
        }
        if let paths = defaults.stringArray(forKey: "wiles_expandedTreePaths") {
            self.expandedTreePaths = Set(paths)
        } else {
            let homePath = home.standardizedFileURL.path
            self.expandedTreePaths = ["/", homePath]
        }
        if let paths = defaults.stringArray(forKey: "wiles_recentOpenedURLs") {
            self.recentOpenedURLs = paths.map { URL(fileURLWithPath: $0) }
        }
        if defaults.object(forKey: "wiles_showTags") != nil {
            self.showTags = defaults.bool(forKey: "wiles_showTags")
        }
        if defaults.object(forKey: "wiles_showFooter") != nil {
            self.showFooter = defaults.bool(forKey: "wiles_showFooter")
        }
        if defaults.object(forKey: "wiles_showPreviewSidebar") != nil {
            self.showPreviewSidebar = defaults.bool(forKey: "wiles_showPreviewSidebar")
        }
        if defaults.object(forKey: "wiles_showTerminalDrawer") != nil {
            self.showTerminalDrawer = defaults.bool(forKey: "wiles_showTerminalDrawer")
        }
        if defaults.object(forKey: "wiles_sidebarTranslucentLevel") != nil {
            self.sidebarTranslucentLevel = defaults.integer(forKey: "wiles_sidebarTranslucentLevel")
        }
        if defaults.object(forKey: "wiles_contentTranslucentLevel") != nil {
            self.contentTranslucentLevel = defaults.integer(forKey: "wiles_contentTranslucentLevel")
        }
        if defaults.object(forKey: "wiles_iconSize") != nil {
            let val = defaults.double(forKey: "wiles_iconSize")
            if val >= 36 && val <= 128 {
                self.iconSize = val
            }
        }
        if let favPaths = defaults.stringArray(forKey: "wiles_favoriteURLs"), !favPaths.isEmpty {
            self.favoriteURLs = favPaths
                .map { URL(fileURLWithPath: $0).standardizedFileURL }
                .filter { $0.path != "/Applications" }
        } else {
            self.favoriteURLs = [
                home,
                home.appendingPathComponent("Desktop"),
                home.appendingPathComponent("Documents"),
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Music"),
                home.appendingPathComponent("Pictures"),
                home.appendingPathComponent("Movies")
            ].map { $0.standardizedFileURL }
        }
        if let data = defaults.data(forKey: "wiles_listColumnStates"),
           let saved = try? JSONDecoder().decode([ListColumnState].self, from: data) {
            // Merge saved states with defaults so new columns added in future are included
            var merged = ListColumnState.defaults()
            for (i, state) in merged.enumerated() {
                if let s = saved.first(where: { $0.column == state.column }) {
                    merged[i] = s
                }
            }
            self.listColumnStates = merged
        }
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
            try? FileSystemService.compressToZIP(urls: urls, in: current)
            await MainActor.run {
                self.refreshCurrentDirectory()
            }
        }
    }
    
    public func extractArchive(url: URL) {
        let current = currentURL
        Task.detached(priority: .userInitiated) {
            try? FileSystemService.extractZIP(archiveURL: url, to: current)
            await MainActor.run {
                self.refreshCurrentDirectory()
            }
        }
    }
    
    public func addToRecents(_ url: URL) {
        let std = url.standardizedFileURL
        if std == AppState.recentsVirtualURL || std.scheme == "wiles" { return }
        var current = recentOpenedURLs.filter { $0.standardizedFileURL != std }
        current.insert(std, at: 0)
        if current.count > 50 {
            current = Array(current.prefix(50))
        }
        self.recentOpenedURLs = current
    }
    
    public func navigateTo(_ url: URL, addToHistory: Bool = true) {
        if url == AppState.recentsVirtualURL {
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
        
        Task {
            let loaded = await FileSystemService.loadDirectoryContents(
                at: target, showHidden: hidden, showTags: tags, searchQuery: query, sortOption: sort, sortAscending: asc
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
