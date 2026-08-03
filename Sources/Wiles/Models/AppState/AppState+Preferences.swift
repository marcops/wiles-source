import Foundation

extension AppState {
    func restoreLayoutPreferences(_ defaults: UserDefaults) {
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
    }

    func restoreSidebarPreferences(_ defaults: UserDefaults, home: URL) {
        if defaults.object(forKey: "wiles_showFavorites") != nil {
            self.showFavorites = defaults.bool(forKey: "wiles_showFavorites")
        }
        if defaults.object(forKey: "wiles_showRecents") != nil {
            self.showRecents = defaults.bool(forKey: "wiles_showRecents")
        }
        if defaults.object(forKey: "wiles_showPlaces") != nil {
            self.showPlaces = defaults.bool(forKey: "wiles_showPlaces")
        }
        if defaults.object(forKey: "wiles_showNetworkAndCloud") != nil {
            self.showNetworkAndCloud = defaults.bool(forKey: "wiles_showNetworkAndCloud")
        }
        if defaults.object(forKey: "wiles_showSidebarSectionTitles") != nil {
            self.showSidebarSectionTitles = defaults.bool(forKey: "wiles_showSidebarSectionTitles")
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
    }

    func restoreDisplayPreferences(_ defaults: UserDefaults) {
        if defaults.object(forKey: "wiles_showHiddenFiles") != nil {
            self.showHiddenFiles = defaults.bool(forKey: "wiles_showHiddenFiles")
        }
        if let langStr = defaults.string(forKey: "wiles_appLanguage"), let lang = AppLanguage(rawValue: langStr) {
            self.appLanguage = lang
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
    }

    func restoreContentPreferences(_ defaults: UserDefaults, home: URL) {
        if let paths = defaults.stringArray(forKey: "wiles_recentOpenedURLs") {
            self.recentOpenedURLs = paths.map { URL(fileURLWithPath: $0) }
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
            for (idx, state) in merged.enumerated() {
                if let savedState = saved.first(where: { $0.column == state.column }) {
                    merged[idx] = savedState
                }
            }
            self.listColumnStates = merged
        }
    }
}
