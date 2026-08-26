import Foundation
import GitBeacon
import Observation
import os

private let columnPersistenceLogger = Logger(subsystem: "com.wiles.app", category: "ColumnPersistence")

/// Adding/removing a `DefaultsKey` needs no migration; *changing* one's stored type/format does — give it a new key name instead.
@Observable
@MainActor
public final class PreferencesStore {
    public var viewMode: ViewMode = .grid {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: DefaultsKey.viewMode.rawValue) }
    }

    public var appAppearance: AppAppearance = .system {
        didSet { UserDefaults.standard.set(appAppearance.rawValue, forKey: DefaultsKey.appAppearance.rawValue) }
    }

    public var showDirectoryTree: Bool = false {
        didSet { UserDefaults.standard.set(showDirectoryTree, forKey: DefaultsKey.showDirectoryTree.rawValue) }
    }

    /// Persisted default for a *new* window's sidebar width — each open window's actual current
    /// width lives on that window's own `WindowUIState.sidebarWidth`, seeded from this at window
    /// construction and written back here on change so the next new window picks up the latest value.
    public var sidebarWidth = Double(LayoutTokens.sidebarIdealWidth) {
        didSet { UserDefaults.standard.set(sidebarWidth, forKey: DefaultsKey.sidebarWidth.rawValue) }
    }

    public var isSidebarCollapsed: Bool = false {
        didSet { UserDefaults.standard.set(isSidebarCollapsed, forKey: DefaultsKey.isSidebarCollapsed.rawValue) }
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
        didSet {
            guard expandedTreePaths.count > Self.maxExpandedTreePaths else {
                scheduleExpandedTreePathsSave()
                return
            }
            // Evict paths that already existed rather than silently reverting the whole
            // assignment — that left disclosure triangles doing nothing once the cap was hit.
            // Prior paths are evicted first; only if that alone isn't enough (e.g. a single
            // assignment that's already over the cap with no prior baseline) does eviction fall
            // back to trimming the newly-added batch itself.
            let overflow = expandedTreePaths.count - Self.maxExpandedTreePaths
            let justAdded = expandedTreePaths.subtracting(oldValue)
            let evictionOrder = Array(oldValue.subtracting(justAdded)) + Array(justAdded)
            expandedTreePaths.subtract(evictionOrder.prefix(overflow))
        }
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

    public var searchCaseSensitive: Bool = false {
        didSet { UserDefaults.standard.set(searchCaseSensitive, forKey: DefaultsKey.searchCaseSensitive.rawValue) }
    }

    /// When on, a search query recurses through the whole user home directory (`URL.userHome`)
    /// instead of just the current folder's direct children.
    public var searchEverywhere: Bool = false {
        didSet { UserDefaults.standard.set(searchEverywhere, forKey: DefaultsKey.searchEverywhere.rawValue) }
    }

    public var showTags: Bool = false {
        didSet { UserDefaults.standard.set(showTags, forKey: DefaultsKey.showTags.rawValue) }
    }

    /// Finder-style middle-ellipsis truncation for long file names (Grid, List) instead of
    /// the default end-only truncation. Defaults on, matching Finder's own behavior.
    public var middleTruncateNames: Bool = true {
        didSet { UserDefaults.standard.set(middleTruncateNames, forKey: DefaultsKey.middleTruncateNames.rawValue) }
    }

    /// When off (default), the path bar collapses to just the current folder and expands to the
    /// full breadcrumb trail on hover. When on, the full path is always shown.
    public var alwaysShowFullPathBar: Bool = false {
        didSet { UserDefaults.standard.set(alwaysShowFullPathBar, forKey: DefaultsKey.alwaysShowFullPathBar.rawValue) }
    }

    public var showFooter: Bool = true {
        didSet { UserDefaults.standard.set(showFooter, forKey: DefaultsKey.showFooter.rawValue) }
    }

    /// Persisted default for a *new* window's terminal drawer — see `sidebarWidth` above for the
    /// seed/write-back pattern. The window's live shell process lives on `WindowUIState`
    /// alongside `terminalViewCache`, never here, so toggling this in one window can't spawn a PTY
    /// in every other open window.
    public var showTerminalDrawer: Bool = false {
        didSet { UserDefaults.standard.set(showTerminalDrawer, forKey: DefaultsKey.showTerminalDrawer.rawValue) }
    }

    /// Persisted default for a *new* window — see `sidebarWidth` above. `showPreviewSidebar` and
    /// `showDiskUsageSidebar` are mutually exclusive: both occupy the same trailing pane of the
    /// content `HSplitView`. Letting both be true at once would put a 3rd pane into that split
    /// view, which `HSplitView`/`NSSplitView` doesn't reliably size on first appearance —
    /// newly-inserted panes there could render at ~0 width instead of honoring their
    /// `.frame(minWidth:)`. Keeping it to a strict 2-pane split (content | one inspector) is the
    /// same shape that already worked correctly, so enforce exclusivity here (and again on
    /// `WindowUIState`, which owns each window's actual live value) instead of fighting
    /// NSSplitView's sizing from the view layer.
    public var showPreviewSidebar: Bool = false {
        didSet {
            UserDefaults.standard.set(showPreviewSidebar, forKey: DefaultsKey.showPreviewSidebar.rawValue)
            if showPreviewSidebar, showDiskUsageSidebar {
                showDiskUsageSidebar = false
            }
        }
    }

    /// Persisted default for a *new* window — see `showPreviewSidebar` above.
    public var showDiskUsageSidebar: Bool = false {
        didSet {
            UserDefaults.standard.set(showDiskUsageSidebar, forKey: DefaultsKey.showDiskUsageSidebar.rawValue)
            if showDiskUsageSidebar, showPreviewSidebar {
                showPreviewSidebar = false
            }
        }
    }

    public var skipDeleteConfirmation: Bool = false {
        didSet { UserDefaults.standard.set(skipDeleteConfirmation, forKey: DefaultsKey.skipDeleteConfirmation.rawValue) }
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

    /// Caps `expandedTreePaths` so an unbounded set of ever-expanded folders isn't retained forever.
    /// Once at the cap, older paths are evicted to make room for newly-expanded ones (see
    /// `expandedTreePaths`'s `didSet`).
    private static let maxExpandedTreePaths = 500
    /// Coalesces rapid expand/collapse toggles into a single `UserDefaults` write.
    private static let expandedTreePathsSaveDebounceInterval: TimeInterval = 0.5
    private var pendingExpandedTreePathsSave: DispatchWorkItem?

    /// Caps `perFolderViewModes` for the same reason as `expandedTreePaths` above.
    private static let maxPerFolderViewModes = 500
    private static let perFolderViewModesSaveDebounceInterval: TimeInterval = 0.5
    private var pendingPerFolderViewModesSave: DispatchWorkItem?

    public var favoriteURLs: [URL] = [] {
        didSet {
            let paths = favoriteURLs.map(\.path)
            UserDefaults.standard.set(paths, forKey: DefaultsKey.favoriteURLs.rawValue)
        }
    }

    /// `private(set)`: mutations must go through the methods below so persistence can't be bypassed.
    public internal(set) var smartFolders: [SmartFolder] = SmartFolderService.loadSavedSmartFolders()

    public var navigationMode: NavigationMode = .gnome {
        didSet { UserDefaults.standard.set(navigationMode.rawValue, forKey: DefaultsKey.navigationMode.rawValue) }
    }

    public var isCompactMode: Bool = false {
        didSet { UserDefaults.standard.set(isCompactMode, forKey: DefaultsKey.isCompactMode.rawValue) }
    }

    public var listColumnStates: [ListColumnState] = ListColumnState.defaults() {
        didSet {
            columnStatesByColumn = Dictionary(uniqueKeysWithValues: listColumnStates.map { ($0.column, $0) })
            guard !suppressColumnStatePersistence else { return }
            saveListColumnStates()
        }
    }

    /// `listColumnStates` keyed by column, kept in sync via `didSet` above — avoids an O(n) array
    /// scan on every per-row/per-column width and visibility lookup while rendering the list.
    public private(set) var columnStatesByColumn: [ListColumn: ListColumnState] =
        Dictionary(uniqueKeysWithValues: ListColumnState.defaults().map { ($0.column, $0) })

    /// When off, `AppState.viewModeForFolder`/`setViewModeForFolder` behave exactly like the single
    /// global `viewMode` did before per-folder view modes existed.
    public var perFolderViewModeEnabled: Bool = false {
        didSet { UserDefaults.standard.set(perFolderViewModeEnabled, forKey: DefaultsKey.perFolderViewModeEnabled.rawValue) }
    }

    public var perFolderViewModes: [String: String] = (
        UserDefaults.standard.dictionary(forKey: DefaultsKey.perFolderViewModes.rawValue) as? [String: String]) ??
        [:] {
        didSet {
            if perFolderViewModes.count > Self.maxPerFolderViewModes {
                perFolderViewModes = oldValue
                return
            }
            schedulePerFolderViewModesSave()
        }
    }

    var suppressColumnStatePersistence: Bool = false

    func saveListColumnStates() {
        do {
            let data = try JSONEncoder().encode(listColumnStates)
            UserDefaults.standard.set(data, forKey: DefaultsKey.listColumnStates.rawValue)
        } catch {
            // Encoding failure here silently drops the user's column widths/visibility on next
            // launch (falls back to defaults) with no other signal, so log it for debugging.
            columnPersistenceLogger.error("Failed to encode listColumnStates: \(error.localizedDescription)")
            ErrorReporter.report(error, context: "Encoding list column states for persistence")
        }
    }

    public var translucentLevel: Int {
        get { sidebarTranslucentLevel }
        set {
            sidebarTranslucentLevel = newValue
            contentTranslucentLevel = newValue
        }
    }

    /// Mirrors `SidebarView.sidebarSectionsContent`'s gating — false hides the whole sidebar pane.
    public var hasVisibleSidebarContent: Bool {
        showRecents ||
            (showFavorites && !favoriteURLs.isEmpty) ||
            showNetworkAndCloud ||
            showPlaces ||
            showDirectoryTree ||
            showTags ||
            !smartFolders.isEmpty
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

    /// Restores a `RawRepresentable<String>`-backed preference (enum settings) if a saved value
    /// exists and is still a recognized case.
    private func loadEnum<T: RawRepresentable>(
        _ key: DefaultsKey, into keyPath: ReferenceWritableKeyPath<PreferencesStore, T>, from defaults: UserDefaults) where T.RawValue == String {
        if let raw = defaults.string(forKey: key.rawValue), let value = T(rawValue: raw) {
            self[keyPath: keyPath] = value
        }
    }

    /// Restores a `Bool` preference, distinguishing "never saved" (leave the property's default)
    /// from an explicitly saved `false` (UserDefaults.bool(forKey:) returns false for both cases).
    private func loadBool(_ key: DefaultsKey, into keyPath: ReferenceWritableKeyPath<PreferencesStore, Bool>, from defaults: UserDefaults) {
        if defaults.object(forKey: key.rawValue) != nil {
            self[keyPath: keyPath] = defaults.bool(forKey: key.rawValue)
        }
    }

    /// Coalesces repeated `expandedTreePaths` edits into one `UserDefaults` write, resetting the
    /// timer on every new toggle so a burst of expand/collapse calls only serializes the set once.
    private func scheduleExpandedTreePathsSave() {
        pendingExpandedTreePathsSave?.cancel()
        let paths = expandedTreePaths
        let workItem = DispatchWorkItem {
            UserDefaults.standard.set(Array(paths), forKey: DefaultsKey.expandedTreePaths.rawValue)
        }
        pendingExpandedTreePathsSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.expandedTreePathsSaveDebounceInterval, execute: workItem)
    }

    /// Coalesces repeated `perFolderViewModes` edits into one `UserDefaults` write, mirroring
    /// `scheduleExpandedTreePathsSave` above.
    private func schedulePerFolderViewModesSave() {
        pendingPerFolderViewModesSave?.cancel()
        let modes = perFolderViewModes
        let workItem = DispatchWorkItem {
            UserDefaults.standard.set(modes, forKey: DefaultsKey.perFolderViewModes.rawValue)
        }
        pendingPerFolderViewModesSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.perFolderViewModesSaveDebounceInterval, execute: workItem)
    }

    private func loadSavedPreferences() {
        let defaults = UserDefaults.standard
        loadViewPreferences(defaults)
        loadSidebarVisibilityPreferences(defaults)
        loadSidebarExpansionPreferences(defaults)
        loadSearchAndDisplayPreferences(defaults)
        loadFavoriteURLs(defaults)
        loadListColumnStates(defaults)
    }

    /// Merges the saved per-column states onto `ListColumnState.defaults()` by `column` rather than
    /// replacing the array wholesale, so a `ListColumn` case added after this data was saved still
    /// gets a default entry instead of silently disappearing from the header/resize logic.
    private func loadListColumnStates(_ defaults: UserDefaults) {
        guard let data = defaults.data(forKey: DefaultsKey.listColumnStates.rawValue),
              let saved = try? JSONDecoder().decode([ListColumnState].self, from: data) else { return }
        let savedByColumn = Dictionary(uniqueKeysWithValues: saved.map { ($0.column, $0) })
        listColumnStates = ListColumnState.defaults().map { savedByColumn[$0.column] ?? $0 }
    }

    private func loadViewPreferences(_ defaults: UserDefaults) {
        loadEnum(.viewMode, into: \.viewMode, from: defaults)
        loadEnum(.appAppearance, into: \.appAppearance, from: defaults)
        loadBool(.showDirectoryTree, into: \.showDirectoryTree, from: defaults)
        loadEnum(.sortOption, into: \.sortOption, from: defaults)
        loadBool(.sortAscending, into: \.sortAscending, from: defaults)
        loadBool(.perFolderViewModeEnabled, into: \.perFolderViewModeEnabled, from: defaults)

        let width = defaults.double(forKey: DefaultsKey.sidebarWidth.rawValue)
        if width > 0 {
            sidebarWidth = width
        }
        loadBool(.isSidebarCollapsed, into: \.isSidebarCollapsed, from: defaults)
    }

    private func loadSidebarVisibilityPreferences(_ defaults: UserDefaults) {
        loadBool(.showHiddenFiles, into: \.showHiddenFiles, from: defaults)
        loadBool(.showFavorites, into: \.showFavorites, from: defaults)
        loadBool(.showRecents, into: \.showRecents, from: defaults)
        loadBool(.showPlaces, into: \.showPlaces, from: defaults)
        loadBool(.showNetworkAndCloud, into: \.showNetworkAndCloud, from: defaults)
        loadBool(.showSidebarSectionTitles, into: \.showSidebarSectionTitles, from: defaults)
        loadEnum(.appLanguage, into: \.appLanguage, from: defaults)
    }

    private func loadSidebarExpansionPreferences(_ defaults: UserDefaults) {
        loadBool(.isFavoritesExpanded, into: \.isFavoritesExpanded, from: defaults)
        loadBool(.isMacExpanded, into: \.isMacExpanded, from: defaults)
        loadBool(.isNetworkExpanded, into: \.isNetworkExpanded, from: defaults)
        loadBool(.isRecentsExpanded, into: \.isRecentsExpanded, from: defaults)
        loadBool(.isDevicesExpanded, into: \.isDevicesExpanded, from: defaults)
        loadBool(.isTreeExpanded, into: \.isTreeExpanded, from: defaults)
        loadBool(.isTagsExpanded, into: \.isTagsExpanded, from: defaults)
        loadBool(.isSmartFoldersExpanded, into: \.isSmartFoldersExpanded, from: defaults)

        if let treePaths = defaults.stringArray(forKey: DefaultsKey.expandedTreePaths.rawValue) {
            expandedTreePaths = Set(treePaths.prefix(Self.maxExpandedTreePaths))
        }
    }

    private func loadSearchAndDisplayPreferences(_ defaults: UserDefaults) {
        loadEnum(.searchScope, into: \.searchScope, from: defaults)
        loadBool(.searchCaseSensitive, into: \.searchCaseSensitive, from: defaults)
        loadBool(.searchEverywhere, into: \.searchEverywhere, from: defaults)
        loadBool(.showTags, into: \.showTags, from: defaults)
        loadBool(.middleTruncateNames, into: \.middleTruncateNames, from: defaults)
        loadBool(.alwaysShowFullPathBar, into: \.alwaysShowFullPathBar, from: defaults)
        loadBool(.showFooter, into: \.showFooter, from: defaults)
        loadBool(.showTerminalDrawer, into: \.showTerminalDrawer, from: defaults)
        loadBool(.showPreviewSidebar, into: \.showPreviewSidebar, from: defaults)
        loadBool(.showDiskUsageSidebar, into: \.showDiskUsageSidebar, from: defaults)
        loadBool(.skipDeleteConfirmation, into: \.skipDeleteConfirmation, from: defaults)
        loadBool(.isCompactMode, into: \.isCompactMode, from: defaults)

        let sLevel = defaults.integer(forKey: DefaultsKey.sidebarTranslucentLevel.rawValue)
        if sLevel > 0 {
            sidebarTranslucentLevel = sLevel
        }
        let cLevel = defaults.integer(forKey: DefaultsKey.contentTranslucentLevel.rawValue)
        if cLevel > 0 {
            contentTranslucentLevel = cLevel
        }
        let iSize = defaults.double(forKey: DefaultsKey.iconSize.rawValue)
        if iSize >= IconSizeToken.minSize, iSize <= IconSizeToken.maxSize {
            iconSize = iSize
        }
    }

    private func loadFavoriteURLs(_ defaults: UserDefaults) {
        if let savedFavs = defaults.stringArray(forKey: DefaultsKey.favoriteURLs.rawValue) {
            favoriteURLs = savedFavs.compactMap { path in
                SlowVolumePathValidator.existsOptimistically(atPath: path) ? URL(fileURLWithPath: path) : nil
            }
            Task { [weak self] in
                await self?.validateSlowVolumeFavorites()
            }
        } else {
            favoriteURLs = [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
            ].filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    /// `/Volumes/` favorites are accepted optimistically above instead of a synchronous
    /// `fileExists` check that could stall init against a sleeping network share (same pattern as
    /// `NavigationStore.init`, mirrored from `AppState+Navigation.swift`'s `navigateTo`). Verifies
    /// them afterward and drops any that turned out to be gone.
    private func validateSlowVolumeFavorites() async {
        let pathsToCheck = Set(favoriteURLs.map(\.path).filter(SlowVolumePathValidator.isLikelySlowVolume))
        guard !pathsToCheck.isEmpty else { return }

        let existence = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: pathsToCheck.map { ($0, FileManager.default.fileExists(atPath: $0)) })
        }.value

        favoriteURLs = favoriteURLs.filter { existence[$0.path] ?? true }
    }
}
