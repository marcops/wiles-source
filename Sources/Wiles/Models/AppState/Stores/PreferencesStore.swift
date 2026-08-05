import Foundation
import Observation

@Observable
@MainActor
public final class PreferencesStore {
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
    public var showTags: Bool = false {
        didSet { UserDefaults.standard.set(showTags, forKey: DefaultsKey.showTags.rawValue) }
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
    public var iconSize: Double = 54.0 {
        didSet { UserDefaults.standard.set(iconSize, forKey: DefaultsKey.iconSize.rawValue) }
    }
    public var favoriteURLs: [URL] = [] {
        didSet {
            let paths = favoriteURLs.map { $0.path }
            UserDefaults.standard.set(paths, forKey: DefaultsKey.favoriteURLs.rawValue)
        }
    }

    public var sidebarOverlayOpacity: Double {
        let base = 1.0 - Double(sidebarTranslucentLevel) / 100.0
        return appAppearance == .light ? base * 0.5 : base
    }

    public var contentOverlayOpacity: Double {
        let base = 1.0 - Double(contentTranslucentLevel) / 100.0
        return appAppearance == .light ? base * 0.5 : base
    }

    public init() {
        loadSavedPreferences()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func loadSavedPreferences() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: DefaultsKey.viewMode.rawValue), let mode = ViewMode(rawValue: raw) {
            self.viewMode = mode
        }
        if let raw = defaults.string(forKey: DefaultsKey.appAppearance.rawValue), let appearance = AppAppearance(rawValue: raw) {
            self.appAppearance = appearance
        }
        if let raw = defaults.string(forKey: DefaultsKey.sidebarMode.rawValue), let mode = SidebarMode(rawValue: raw) {
            self.sidebarMode = mode
        }
        let width = defaults.double(forKey: DefaultsKey.sidebarWidth.rawValue)
        if width > 0 { self.sidebarWidth = width }

        if let raw = defaults.string(forKey: DefaultsKey.sortOption.rawValue), let opt = SortOption(rawValue: raw) {
            self.sortOption = opt
        }
        if defaults.object(forKey: DefaultsKey.sortAscending.rawValue) != nil {
            self.sortAscending = defaults.bool(forKey: DefaultsKey.sortAscending.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showHiddenFiles.rawValue) != nil {
            self.showHiddenFiles = defaults.bool(forKey: DefaultsKey.showHiddenFiles.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showFavorites.rawValue) != nil {
            self.showFavorites = defaults.bool(forKey: DefaultsKey.showFavorites.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showRecents.rawValue) != nil {
            self.showRecents = defaults.bool(forKey: DefaultsKey.showRecents.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showPlaces.rawValue) != nil {
            self.showPlaces = defaults.bool(forKey: DefaultsKey.showPlaces.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showNetworkAndCloud.rawValue) != nil {
            self.showNetworkAndCloud = defaults.bool(forKey: DefaultsKey.showNetworkAndCloud.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showSidebarSectionTitles.rawValue) != nil {
            self.showSidebarSectionTitles = defaults.bool(forKey: DefaultsKey.showSidebarSectionTitles.rawValue)
        }
        if let raw = defaults.string(forKey: DefaultsKey.appLanguage.rawValue), let lang = AppLanguage(rawValue: raw) {
            self.appLanguage = lang
        }
        if defaults.object(forKey: DefaultsKey.isFavoritesExpanded.rawValue) != nil {
            self.isFavoritesExpanded = defaults.bool(forKey: DefaultsKey.isFavoritesExpanded.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.isMacExpanded.rawValue) != nil {
            self.isMacExpanded = defaults.bool(forKey: DefaultsKey.isMacExpanded.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.isNetworkExpanded.rawValue) != nil {
            self.isNetworkExpanded = defaults.bool(forKey: DefaultsKey.isNetworkExpanded.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.isRecentsExpanded.rawValue) != nil {
            self.isRecentsExpanded = defaults.bool(forKey: DefaultsKey.isRecentsExpanded.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.isDevicesExpanded.rawValue) != nil {
            self.isDevicesExpanded = defaults.bool(forKey: DefaultsKey.isDevicesExpanded.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.isTreeExpanded.rawValue) != nil {
            self.isTreeExpanded = defaults.bool(forKey: DefaultsKey.isTreeExpanded.rawValue)
        }
        if let treePaths = defaults.stringArray(forKey: DefaultsKey.expandedTreePaths.rawValue) {
            self.expandedTreePaths = Set(treePaths)
        }
        if defaults.object(forKey: DefaultsKey.isTagsExpanded.rawValue) != nil {
            self.isTagsExpanded = defaults.bool(forKey: DefaultsKey.isTagsExpanded.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.isSmartFoldersExpanded.rawValue) != nil {
            self.isSmartFoldersExpanded = defaults.bool(forKey: DefaultsKey.isSmartFoldersExpanded.rawValue)
        }
        if let raw = defaults.string(forKey: DefaultsKey.searchScope.rawValue), let scope = SearchScope(rawValue: raw) {
            self.searchScope = scope
        }
        if defaults.object(forKey: DefaultsKey.showTags.rawValue) != nil {
            self.showTags = defaults.bool(forKey: DefaultsKey.showTags.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showFooter.rawValue) != nil {
            self.showFooter = defaults.bool(forKey: DefaultsKey.showFooter.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showTerminalDrawer.rawValue) != nil {
            self.showTerminalDrawer = defaults.bool(forKey: DefaultsKey.showTerminalDrawer.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showPreviewSidebar.rawValue) != nil {
            self.showPreviewSidebar = defaults.bool(forKey: DefaultsKey.showPreviewSidebar.rawValue)
        }
        let sLevel = defaults.integer(forKey: DefaultsKey.sidebarTranslucentLevel.rawValue)
        if sLevel > 0 { self.sidebarTranslucentLevel = sLevel }
        let cLevel = defaults.integer(forKey: DefaultsKey.contentTranslucentLevel.rawValue)
        if cLevel > 0 { self.contentTranslucentLevel = cLevel }
        let iSize = defaults.double(forKey: DefaultsKey.iconSize.rawValue)
        if iSize >= IconSizeToken.minSize && iSize <= IconSizeToken.maxSize {
            self.iconSize = iSize
        }

        if let savedFavs = defaults.stringArray(forKey: DefaultsKey.favoriteURLs.rawValue) {
            self.favoriteURLs = savedFavs.compactMap { path in
                FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
            }
        } else {
            self.favoriteURLs = [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
            ].filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }
}
