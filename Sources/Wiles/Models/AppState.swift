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
    public var favoriteURLs: [URL] = [] {
        didSet {
            let paths = favoriteURLs.map { $0.path }
            UserDefaults.standard.set(paths, forKey: "wiles_favoriteURLs")
        }
    }
    public var showHelpSheet: Bool = false
    
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
    public var showNewFolderSheet: Bool = false
    
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
