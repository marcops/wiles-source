@testable import Wiles
import Foundation

@MainActor
public struct AppStatePreferencesTests {
    public static func run() {
        testRestoreLayoutPreferences()
        testRestoreSidebarPreferences()
        testRestoreDisplayPreferences()
        testRestoreContentPreferences()
    }

    private static func makeDefaults() -> UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite \(suiteName)")
        }
        return defaults
    }

    // MARK: - restoreLayoutPreferences

    private static func testRestoreLayoutPreferences() {
        testRestoreLayoutPreferencesBasic()
        testRestoreLayoutPreferencesClamping()
        testRestoreLayoutPreferencesEmptyDefaults()
        testRestoreLayoutPreferencesInvalidValue()
    }

    private static func testRestoreLayoutPreferencesBasic() {
        let appState = AppState()
        let defaults = makeDefaults()

        defaults.set(SidebarMode.tree.rawValue, forKey: DefaultsKey.sidebarMode.rawValue)
        defaults.set(200.0, forKey: DefaultsKey.sidebarWidth.rawValue)
        defaults.set(NavigationMode.macOS.rawValue, forKey: DefaultsKey.navigationMode.rawValue)
        defaults.set(ViewMode.list.rawValue, forKey: DefaultsKey.viewMode.rawValue)
        defaults.set(AppAppearance.dark.rawValue, forKey: DefaultsKey.appAppearance.rawValue)
        defaults.set(SortOption.size.rawValue, forKey: DefaultsKey.sortOption.rawValue)
        defaults.set(false, forKey: DefaultsKey.sortAscending.rawValue)

        appState.restoreLayoutPreferences(defaults)
        report("AppState+Preferences", "POS: restoreLayoutPreferences() restores sidebarMode/navigationMode/viewMode/appAppearance/sortOption/sortAscending from defaults", result:
            appState.sidebarMode == .tree &&
            appState.navigationMode == .macOS &&
            appState.viewMode == .list &&
            appState.appAppearance == .dark &&
            appState.sortOption == .size &&
            appState.sortAscending == false)
        report("AppState+Preferences", "POS: restoreLayoutPreferences() restores an in-range sidebarWidth as-is", result: appState.sidebarWidth == 200.0)
    }

    private static func testRestoreLayoutPreferencesClamping() {
        // Clamping
        let appStateClampHigh = AppState()
        let defaultsHigh = makeDefaults()
        defaultsHigh.set(9999.0, forKey: DefaultsKey.sidebarWidth.rawValue)
        appStateClampHigh.restoreLayoutPreferences(defaultsHigh)
        report(
            "AppState+Preferences",
            "POS: restoreLayoutPreferences() clamps an oversized sidebarWidth to LayoutTokens.sidebarMaxWidth",
            result: appStateClampHigh.sidebarWidth == Double(LayoutTokens.sidebarMaxWidth)
        )

        let appStateClampLow = AppState()
        let defaultsLow = makeDefaults()
        defaultsLow.set(1.0, forKey: DefaultsKey.sidebarWidth.rawValue)
        appStateClampLow.restoreLayoutPreferences(defaultsLow)
        report(
            "AppState+Preferences",
            "POS: restoreLayoutPreferences() clamps an undersized sidebarWidth to LayoutTokens.sidebarMinWidth",
            result: appStateClampLow.sidebarWidth == Double(LayoutTokens.sidebarMinWidth)
        )
    }

    private static func testRestoreLayoutPreferencesEmptyDefaults() {
        // Negative: nothing set, values remain at AppState() defaults
        let freshState = AppState()
        let emptyDefaults = makeDefaults()
        let defaultSidebarMode = freshState.sidebarMode
        let defaultSidebarWidth = freshState.sidebarWidth
        let defaultNavigationMode = freshState.navigationMode
        let defaultViewMode = freshState.viewMode
        let defaultAppearance = freshState.appAppearance
        let defaultSortOption = freshState.sortOption
        let defaultSortAscending = freshState.sortAscending

        freshState.restoreLayoutPreferences(emptyDefaults)
        report("AppState+Preferences", "NEG: restoreLayoutPreferences() with empty defaults leaves all layout properties at AppState() defaults", result:
            freshState.sidebarMode == defaultSidebarMode &&
            freshState.sidebarWidth == defaultSidebarWidth &&
            freshState.navigationMode == defaultNavigationMode &&
            freshState.viewMode == defaultViewMode &&
            freshState.appAppearance == defaultAppearance &&
            freshState.sortOption == defaultSortOption &&
            freshState.sortAscending == defaultSortAscending)
    }

    private static func testRestoreLayoutPreferencesInvalidValue() {
        // Negative: invalid raw value strings are ignored
        let invalidState = AppState()
        let invalidDefaults = makeDefaults()
        let priorSidebarMode = invalidState.sidebarMode
        invalidDefaults.set("NotARealMode", forKey: DefaultsKey.sidebarMode.rawValue)
        invalidState.restoreLayoutPreferences(invalidDefaults)
        report(
            "AppState+Preferences",
            "NEG: restoreLayoutPreferences() ignores an unrecognized sidebarMode raw value",
            result: invalidState.sidebarMode == priorSidebarMode
        )
    }

    // MARK: - restoreSidebarPreferences

    private static func testRestoreSidebarPreferences() {
        let home = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("home-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let fallbackDefaults = testRestoreSidebarPreferencesBasic(home: home)
        testRestoreSidebarPreferencesFallback(home: home, fallbackDefaults: fallbackDefaults)
        testRestoreSidebarPreferencesUntouched(home: home, fallbackDefaults: fallbackDefaults)
    }

    private static func testRestoreSidebarPreferencesBasic(home: URL) -> UserDefaults {
        let appState = AppState()
        let defaults = makeDefaults()
        defaults.set(false, forKey: DefaultsKey.showFavorites.rawValue)
        defaults.set(false, forKey: DefaultsKey.showRecents.rawValue)
        defaults.set(false, forKey: DefaultsKey.showPlaces.rawValue)
        defaults.set(false, forKey: DefaultsKey.showNetworkAndCloud.rawValue)
        defaults.set(false, forKey: DefaultsKey.showSidebarSectionTitles.rawValue)
        defaults.set(true, forKey: DefaultsKey.isFavoritesExpanded.rawValue)
        defaults.set(true, forKey: DefaultsKey.isMacExpanded.rawValue)
        defaults.set(true, forKey: DefaultsKey.isNetworkExpanded.rawValue)
        defaults.set(true, forKey: DefaultsKey.isRecentsExpanded.rawValue)
        defaults.set(true, forKey: DefaultsKey.isDevicesExpanded.rawValue)
        defaults.set(true, forKey: DefaultsKey.isTreeExpanded.rawValue)
        defaults.set(["/foo", "/bar"], forKey: DefaultsKey.expandedTreePaths.rawValue)

        appState.restoreSidebarPreferences(defaults, home: home)
        report("AppState+Preferences", "POS: restoreSidebarPreferences() restores all show*/is*Expanded booleans from defaults", result:
            appState.showFavorites == false &&
            appState.showRecents == false &&
            appState.showPlaces == false &&
            appState.showNetworkAndCloud == false &&
            appState.showSidebarSectionTitles == false &&
            appState.isFavoritesExpanded == true &&
            appState.isMacExpanded == true &&
            appState.isNetworkExpanded == true &&
            appState.isRecentsExpanded == true &&
            appState.isDevicesExpanded == true &&
            appState.isTreeExpanded == true)
        report(
            "AppState+Preferences",
            "POS: restoreSidebarPreferences() restores expandedTreePaths from a saved string array",
            result: appState.expandedTreePaths == Set(["/foo", "/bar"])
        )
        return makeDefaults()
    }

    private static func testRestoreSidebarPreferencesFallback(home: URL, fallbackDefaults: UserDefaults) {
        // Negative: expandedTreePaths key absent falls back to ["/", home]
        let fallbackState = AppState()
        fallbackState.restoreSidebarPreferences(fallbackDefaults, home: home)
        let expectedFallback = Set(["/", home.standardizedFileURL.path])
        report(
            "AppState+Preferences",
            "NEG: restoreSidebarPreferences() falls back to [\"/\", home path] when expandedTreePaths key is absent",
            result: fallbackState.expandedTreePaths == expectedFallback
        )
    }

    private static func testRestoreSidebarPreferencesUntouched(home: URL, fallbackDefaults: UserDefaults) {
        // Negative: booleans untouched when keys absent
        let untouchedState = AppState()
        let priorShowFavorites = untouchedState.showFavorites
        let priorIsTreeExpanded = untouchedState.isTreeExpanded
        untouchedState.restoreSidebarPreferences(fallbackDefaults, home: home)
        report("AppState+Preferences", "NEG: restoreSidebarPreferences() leaves showFavorites/isTreeExpanded unchanged when their keys are absent", result:
            untouchedState.showFavorites == priorShowFavorites && untouchedState.isTreeExpanded == priorIsTreeExpanded)
    }

    // MARK: - restoreDisplayPreferences

    private static func testRestoreDisplayPreferences() {
        testRestoreDisplayPreferencesBasic()
        testRestoreDisplayPreferencesIconSizeClamping()
        testRestoreDisplayPreferencesEmptyDefaults()
    }

    private static func testRestoreDisplayPreferencesBasic() {
        let appState = AppState()
        let defaults = makeDefaults()
        defaults.set(true, forKey: DefaultsKey.showHiddenFiles.rawValue)
        defaults.set(AppLanguage.french.rawValue, forKey: DefaultsKey.appLanguage.rawValue)
        defaults.set(true, forKey: DefaultsKey.showTags.rawValue)
        defaults.set(false, forKey: DefaultsKey.showFooter.rawValue)
        defaults.set(false, forKey: DefaultsKey.showPreviewSidebar.rawValue)
        defaults.set(true, forKey: DefaultsKey.showTerminalDrawer.rawValue)
        defaults.set(2, forKey: DefaultsKey.sidebarTranslucentLevel.rawValue)
        defaults.set(3, forKey: DefaultsKey.contentTranslucentLevel.rawValue)
        defaults.set(64.0, forKey: DefaultsKey.iconSize.rawValue)

        appState.restoreDisplayPreferences(defaults)
        report(
            "AppState+Preferences",
            "POS: restoreDisplayPreferences() restores showHiddenFiles/appLanguage/showTags/showFooter/showPreviewSidebar/showTerminalDrawer/translucency levels",
            result:
            appState.showHiddenFiles == true &&
            appState.appLanguage == .french &&
            appState.showTags == true &&
            appState.showFooter == false &&
            appState.showPreviewSidebar == false &&
            appState.showTerminalDrawer == true &&
            appState.sidebarTranslucentLevel == 2 &&
            appState.contentTranslucentLevel == 3)
        report(
            "AppState+Preferences",
            "POS: restoreDisplayPreferences() applies an in-range iconSize (64, within 36...128)",
            result: appState.iconSize == 64.0
        )
    }

    private static func testRestoreDisplayPreferencesIconSizeClamping() {
        // Negative: out-of-range iconSize values are rejected, prior value retained
        let lowState = AppState()
        let priorLowIconSize = lowState.iconSize
        let lowDefaults = makeDefaults()
        lowDefaults.set(10.0, forKey: DefaultsKey.iconSize.rawValue)
        lowState.restoreDisplayPreferences(lowDefaults)
        report(
            "AppState+Preferences",
            "NEG: restoreDisplayPreferences() rejects an out-of-range low iconSize (10), leaving prior value unchanged",
            result: lowState.iconSize == priorLowIconSize
        )

        let highState = AppState()
        let priorHighIconSize = highState.iconSize
        let highDefaults = makeDefaults()
        highDefaults.set(200.0, forKey: DefaultsKey.iconSize.rawValue)
        highState.restoreDisplayPreferences(highDefaults)
        report(
            "AppState+Preferences",
            "NEG: restoreDisplayPreferences() rejects an out-of-range high iconSize (200), leaving prior value unchanged",
            result: highState.iconSize == priorHighIconSize
        )
    }

    private static func testRestoreDisplayPreferencesEmptyDefaults() {
        // Negative: empty defaults leave all display properties at prior/default values
        let freshState = AppState()
        let priorShowHiddenFiles = freshState.showHiddenFiles
        let priorAppLanguage = freshState.appLanguage
        let emptyDefaults = makeDefaults()
        freshState.restoreDisplayPreferences(emptyDefaults)
        report("AppState+Preferences", "NEG: restoreDisplayPreferences() with empty defaults leaves showHiddenFiles/appLanguage at AppState() defaults", result:
            freshState.showHiddenFiles == priorShowHiddenFiles && freshState.appLanguage == priorAppLanguage)
    }

    // MARK: - restoreContentPreferences

    private static func testRestoreContentPreferences() {
        let home = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("home-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        testRestoreContentPreferencesRecents(home: home)
        testRestoreContentPreferencesFavorites(home: home)
        testRestoreContentPreferencesListColumnStates(home: home)
    }

    private static func testRestoreContentPreferencesRecents(home: URL) {
        // recentOpenedURLs
        let appState = AppState()
        let defaults = makeDefaults()
        let recentPaths = ["/tmp/one.txt", "/tmp/two.txt"]
        defaults.set(recentPaths, forKey: DefaultsKey.recentOpenedURLs.rawValue)
        appState.restoreContentPreferences(defaults, home: home)
        report("AppState+Preferences", "POS: restoreContentPreferences() restores recentOpenedURLs from a saved string array", result:
            appState.recentOpenedURLs.map { $0.path } == recentPaths.map { URL(fileURLWithPath: $0).path })
    }

    private static func testRestoreContentPreferencesFavorites(home: URL) {
        // favoriteURLs: /Applications filtered out
        let favState = AppState()
        let favDefaults = makeDefaults()
        favDefaults.set(["/Applications", "/Users/someone/Documents", "/Users/someone/Downloads"], forKey: DefaultsKey.favoriteURLs.rawValue)
        favState.restoreContentPreferences(favDefaults, home: home)
        let favPaths = favState.favoriteURLs.map { $0.path }
        report("AppState+Preferences", "POS: restoreContentPreferences() filters out an /Applications entry from saved favoriteURLs", result:
            !favPaths.contains("/Applications") &&
            favPaths.contains("/Users/someone/Documents") &&
            favPaths.contains("/Users/someone/Downloads") &&
            favState.favoriteURLs.count == 2)

        // favoriteURLs: fallback to the 7 default well-known folders when key absent
        let fallbackFavState = AppState()
        let fallbackFavDefaults = makeDefaults()
        fallbackFavState.restoreContentPreferences(fallbackFavDefaults, home: home)
        let expectedFallbackFavorites = [
            home,
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Music"),
            home.appendingPathComponent("Pictures"),
            home.appendingPathComponent("Movies")
        ].map { $0.standardizedFileURL.path }
        report("AppState+Preferences", "NEG: restoreContentPreferences() falls back to the 7 default well-known folders when favoriteURLs key is absent", result:
            fallbackFavState.favoriteURLs.count == 7 &&
            fallbackFavState.favoriteURLs.map { $0.path } == expectedFallbackFavorites)
    }

    private static func testRestoreContentPreferencesListColumnStates(home: URL) {
        // listColumnStates: merge saved subset onto defaults
        let colState = AppState()
        let colDefaults = makeDefaults()
        let savedColumns: [ListColumnState] = [
            ListColumnState(column: .size, width: 555, isVisible: true),
            ListColumnState(column: .kind, width: 321, isVisible: true)
        ]
        let encoded = try? JSONEncoder().encode(savedColumns)
        colDefaults.set(encoded, forKey: DefaultsKey.listColumnStates.rawValue)
        colState.restoreContentPreferences(colDefaults, home: home)

        let defaultsBaseline = ListColumnState.defaults()
        func stateFor(_ col: ListColumn, in states: [ListColumnState]) -> ListColumnState? {
            states.first { $0.column == col }
        }
        let mergedSize = stateFor(.size, in: colState.listColumnStates)
        let mergedKind = stateFor(.kind, in: colState.listColumnStates)
        let mergedName = stateFor(.name, in: colState.listColumnStates)
        let defaultName = stateFor(.name, in: defaultsBaseline)
        let mergedOwner = stateFor(.owner, in: colState.listColumnStates)
        let defaultOwner = stateFor(.owner, in: defaultsBaseline)

        report("AppState+Preferences", "POS: restoreContentPreferences() overrides listColumnStates entries present in the saved array", result:
            mergedSize?.width == 555 && mergedSize?.isVisible == true &&
            mergedKind?.width == 321 && mergedKind?.isVisible == true)
        report("AppState+Preferences", "POS: restoreContentPreferences() keeps ListColumnState.defaults() values for columns absent from the saved array", result:
            mergedName?.width == defaultName?.width && mergedName?.isVisible == defaultName?.isVisible &&
            mergedOwner?.width == defaultOwner?.width && mergedOwner?.isVisible == defaultOwner?.isVisible)
        report(
            "AppState+Preferences",
            "POS: restoreContentPreferences() produces a listColumnStates array covering all ListColumn cases",
            result: colState.listColumnStates.count == ListColumn.allCases.count
        )

        // Negative: no listColumnStates key present, listColumnStates untouched (stays at AppState() default)
        let untouchedColState = AppState()
        let priorListColumnStates = untouchedColState.listColumnStates.map { $0.width }
        let emptyDefaults = makeDefaults()
        untouchedColState.restoreContentPreferences(emptyDefaults, home: home)
        report("AppState+Preferences", "NEG: restoreContentPreferences() leaves listColumnStates unchanged when the key is absent", result:
            untouchedColState.listColumnStates.map { $0.width } == priorListColumnStates)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
