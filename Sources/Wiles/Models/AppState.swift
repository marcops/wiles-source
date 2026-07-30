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
    
    public var viewMode: ViewMode = .grid {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "wiles_viewMode") }
    }
    public var sidebarMode: SidebarMode = .places {
        didSet { UserDefaults.standard.set(sidebarMode.rawValue, forKey: "wiles_sidebarMode") }
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
    public var showMacSection: Bool = true {
        didSet { UserDefaults.standard.set(showMacSection, forKey: "wiles_showMacSection") }
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
    public var showFooter: Bool = true {
        didSet { UserDefaults.standard.set(showFooter, forKey: "wiles_showFooter") }
    }
    public var showPreviewSidebar: Bool = false {
        didSet { UserDefaults.standard.set(showPreviewSidebar, forKey: "wiles_showPreviewSidebar") }
    }
    public var translucentLevel: Int = 60 {
        didSet { UserDefaults.standard.set(translucentLevel, forKey: "wiles_translucentLevel") }
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
    public var showBatchRenameSheet: Bool = false
    public var showDiskUsageSheet: Bool = false
    public var showNewFolderSheet: Bool = false
    public var showNewFileSheet: Bool = false
    
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
        if let navStr = defaults.string(forKey: "wiles_navigationMode"), let mode = NavigationMode(rawValue: navStr) {
            self.navigationMode = mode
        }
        if let viewStr = defaults.string(forKey: "wiles_viewMode"), let mode = ViewMode(rawValue: viewStr) {
            self.viewMode = mode
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
        if let langStr = defaults.string(forKey: "wiles_appLanguage"), let lang = AppLanguage(rawValue: langStr) {
            self.appLanguage = lang
        }
        if defaults.object(forKey: "wiles_isFavoritesExpanded") != nil {
            self.isFavoritesExpanded = defaults.bool(forKey: "wiles_isFavoritesExpanded")
        }
        if defaults.object(forKey: "wiles_isMacExpanded") != nil {
            self.isMacExpanded = defaults.bool(forKey: "wiles_isMacExpanded")
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
        if defaults.object(forKey: "wiles_showFooter") != nil {
            self.showFooter = defaults.bool(forKey: "wiles_showFooter")
        }
        if defaults.object(forKey: "wiles_showPreviewSidebar") != nil {
            self.showPreviewSidebar = defaults.bool(forKey: "wiles_showPreviewSidebar")
        }
        if defaults.object(forKey: "wiles_translucentLevel") != nil {
            self.translucentLevel = defaults.integer(forKey: "wiles_translucentLevel")
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
    
    public func navigateTo(_ url: URL, addToHistory: Bool = true) {
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
        let query = searchQuery
        let sort = sortOption
        let asc = sortAscending
        
        Task {
            let loaded = await FileSystemService.loadDirectoryContents(
                at: target, showHidden: hidden, searchQuery: query, sortOption: sort, sortAscending: asc
            )
            if self.currentURL == target {
                self.items = loaded
                self.isLoading = false
            }
        }
    }
}
