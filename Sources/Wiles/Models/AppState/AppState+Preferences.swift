import Foundation

extension AppState {
    func restoreLayoutPreferences(_ defaults: UserDefaults) {
        if let modeStr = defaults.string(forKey: DefaultsKey.sidebarMode.rawValue), let mode = SidebarMode(rawValue: modeStr) {
            self.sidebarMode = mode
        }
        if defaults.object(forKey: DefaultsKey.sidebarWidth.rawValue) != nil {
            let savedWidth = defaults.double(forKey: DefaultsKey.sidebarWidth.rawValue)
            self.sidebarWidth = min(Double(LayoutTokens.sidebarMaxWidth), max(Double(LayoutTokens.sidebarMinWidth), savedWidth))
        }
        if let navStr = defaults.string(forKey: DefaultsKey.navigationMode.rawValue), let mode = NavigationMode(rawValue: navStr) {
            self.navigationMode = mode
        }
        if let viewStr = defaults.string(forKey: DefaultsKey.viewMode.rawValue), let mode = ViewMode(rawValue: viewStr) {
            self.viewMode = mode
        }
        if let appearanceStr = defaults.string(forKey: DefaultsKey.appAppearance.rawValue), let appearance = AppAppearance(rawValue: appearanceStr) {
            self.appAppearance = appearance
        }
        if let sortStr = defaults.string(forKey: DefaultsKey.sortOption.rawValue), let opt = SortOption(rawValue: sortStr) {
            self.sortOption = opt
        }
        if defaults.object(forKey: DefaultsKey.sortAscending.rawValue) != nil {
            self.sortAscending = defaults.bool(forKey: DefaultsKey.sortAscending.rawValue)
        }
    }

    func restoreSidebarPreferences(_ defaults: UserDefaults, home: URL) {
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
        if let paths = defaults.stringArray(forKey: DefaultsKey.expandedTreePaths.rawValue) {
            self.expandedTreePaths = Set(paths)
        } else {
            let homePath = home.standardizedFileURL.path
            self.expandedTreePaths = ["/", homePath]
        }
    }

    func restoreDisplayPreferences(_ defaults: UserDefaults) {
        if defaults.object(forKey: DefaultsKey.showHiddenFiles.rawValue) != nil {
            self.showHiddenFiles = defaults.bool(forKey: DefaultsKey.showHiddenFiles.rawValue)
        }
        if let langStr = defaults.string(forKey: DefaultsKey.appLanguage.rawValue), let lang = AppLanguage(rawValue: langStr) {
            self.appLanguage = lang
        }
        if defaults.object(forKey: DefaultsKey.showTags.rawValue) != nil {
            self.showTags = defaults.bool(forKey: DefaultsKey.showTags.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showFooter.rawValue) != nil {
            self.showFooter = defaults.bool(forKey: DefaultsKey.showFooter.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showPreviewSidebar.rawValue) != nil {
            self.showPreviewSidebar = defaults.bool(forKey: DefaultsKey.showPreviewSidebar.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.showTerminalDrawer.rawValue) != nil {
            self.showTerminalDrawer = defaults.bool(forKey: DefaultsKey.showTerminalDrawer.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.sidebarTranslucentLevel.rawValue) != nil {
            self.sidebarTranslucentLevel = defaults.integer(forKey: DefaultsKey.sidebarTranslucentLevel.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.contentTranslucentLevel.rawValue) != nil {
            self.contentTranslucentLevel = defaults.integer(forKey: DefaultsKey.contentTranslucentLevel.rawValue)
        }
        if defaults.object(forKey: DefaultsKey.iconSize.rawValue) != nil {
            let val = defaults.double(forKey: DefaultsKey.iconSize.rawValue)
            if val >= 36 && val <= 128 {
                self.iconSize = val
            }
        }
    }

    func restoreContentPreferences(_ defaults: UserDefaults, home: URL) {
        if let paths = defaults.stringArray(forKey: DefaultsKey.recentOpenedURLs.rawValue) {
            self.recentOpenedURLs = paths.map { URL(fileURLWithPath: $0) }
        }
        if let favPaths = defaults.stringArray(forKey: DefaultsKey.favoriteURLs.rawValue), !favPaths.isEmpty {
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
        if let data = defaults.data(forKey: DefaultsKey.listColumnStates.rawValue),
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
