import Foundation
import GitBeacon
import Observation

/// Adding/removing a `DefaultsKey` needs no migration; *changing* one's stored type/format does — give it a new key name instead.
@Observable
@MainActor
public final class PreferencesStore {
    public var viewMode: ViewMode = .grid {
        didSet { persist(viewMode, .viewMode) }
    }

    public var appAppearance: AppAppearance = .system {
        didSet { persist(appAppearance, .appAppearance) }
    }

    public var showDirectoryTree: Bool = false {
        didSet { persist(showDirectoryTree, .showDirectoryTree) }
    }

    /// Persisted default for a *new* window's sidebar width — each open window's actual current
    /// width lives on that window's own `WindowUIState.sidebarWidth`, seeded from this at window
    /// construction and written back here on change so the next new window picks up the latest value.
    public var sidebarWidth = Double(LayoutTokens.sidebarIdealWidth) {
        didSet { persist(sidebarWidth, .sidebarWidth) }
    }

    public var isSidebarCollapsed: Bool = false {
        didSet { persist(isSidebarCollapsed, .isSidebarCollapsed) }
    }

    public var sortOption: SortOption = .name {
        didSet { persist(sortOption, .sortOption) }
    }

    public var sortAscending: Bool = true {
        didSet { persist(sortAscending, .sortAscending) }
    }

    public var showHiddenFiles: Bool = false {
        didSet { persist(showHiddenFiles, .showHiddenFiles) }
    }

    public var showFavorites: Bool = true {
        didSet { persist(showFavorites, .showFavorites) }
    }

    public var showRecents: Bool = true {
        didSet { persist(showRecents, .showRecents) }
    }

    public var showPlaces: Bool = true {
        didSet { persist(showPlaces, .showPlaces) }
    }

    public var showNetworkAndCloud: Bool = false {
        didSet { persist(showNetworkAndCloud, .showNetworkAndCloud) }
    }

    public var showSidebarSectionTitles: Bool = true {
        didSet { persist(showSidebarSectionTitles, .showSidebarSectionTitles) }
    }

    public var appLanguage: AppLanguage = .system {
        didSet { persist(appLanguage, .appLanguage) }
    }

    public var isFavoritesExpanded: Bool = true {
        didSet { persist(isFavoritesExpanded, .isFavoritesExpanded) }
    }

    public var isMacExpanded: Bool = true {
        didSet { persist(isMacExpanded, .isMacExpanded) }
    }

    public var isNetworkExpanded: Bool = true {
        didSet { persist(isNetworkExpanded, .isNetworkExpanded) }
    }

    public var isRecentsExpanded: Bool = true {
        didSet { persist(isRecentsExpanded, .isRecentsExpanded) }
    }

    public var isDevicesExpanded: Bool = true {
        didSet { persist(isDevicesExpanded, .isDevicesExpanded) }
    }

    public var isTreeExpanded: Bool = true {
        didSet { persist(isTreeExpanded, .isTreeExpanded) }
    }

    public var expandedTreePaths: Set<String> = [] {
        didSet {
            guard expandedTreePaths.count > Self.maxExpandedTreePaths else {
                scheduleExpandedTreePathsSave()
                return
            }
            expandedTreePaths.subtract(Self.keysToEvict(
                current: expandedTreePaths, previous: oldValue, cap: Self.maxExpandedTreePaths))
        }
    }

    public var isTagsExpanded: Bool = true {
        didSet { persist(isTagsExpanded, .isTagsExpanded) }
    }

    public var isSmartFoldersExpanded: Bool = true {
        didSet { persist(isSmartFoldersExpanded, .isSmartFoldersExpanded) }
    }

    public var searchScope: SearchScope = .name {
        didSet { persist(searchScope, .searchScope) }
    }

    public var searchCaseSensitive: Bool = false {
        didSet { persist(searchCaseSensitive, .searchCaseSensitive) }
    }

    /// When on, a search query recurses through the whole user home directory (`URL.userHome`)
    /// instead of just the current folder's direct children.
    public var searchEverywhere: Bool = false {
        didSet { persist(searchEverywhere, .searchEverywhere) }
    }

    public var showTags: Bool = false {
        didSet { persist(showTags, .showTags) }
    }

    /// Finder-style middle-ellipsis truncation for long file names (Grid, List) instead of
    /// the default end-only truncation. Defaults on, matching Finder's own behavior.
    public var middleTruncateNames: Bool = true {
        didSet { persist(middleTruncateNames, .middleTruncateNames) }
    }

    /// When off (default), the path bar collapses to just the current folder and expands to the
    /// full breadcrumb trail on hover. When on, the full path is always shown.
    public var alwaysShowFullPathBar: Bool = false {
        didSet { persist(alwaysShowFullPathBar, .alwaysShowFullPathBar) }
    }

    public var showFooter: Bool = true {
        didSet { persist(showFooter, .showFooter) }
    }

    /// Persisted default for a *new* window's terminal drawer — see `sidebarWidth` above for the
    /// seed/write-back pattern. The window's live shell process lives on `WindowUIState`
    /// alongside `terminalViewCache`, never here, so toggling this in one window can't spawn a PTY
    /// in every other open window.
    public var showTerminalDrawer: Bool = false {
        didSet { persist(showTerminalDrawer, .showTerminalDrawer) }
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
            persist(showPreviewSidebar, .showPreviewSidebar)
            if showPreviewSidebar, showDiskUsageSidebar {
                showDiskUsageSidebar = false
            }
        }
    }

    /// Persisted default for a *new* window — see `showPreviewSidebar` above.
    public var showDiskUsageSidebar: Bool = false {
        didSet {
            persist(showDiskUsageSidebar, .showDiskUsageSidebar)
            if showDiskUsageSidebar, showPreviewSidebar {
                showPreviewSidebar = false
            }
        }
    }

    public var skipDeleteConfirmation: Bool = false {
        didSet { persist(skipDeleteConfirmation, .skipDeleteConfirmation) }
    }

    public var sidebarTranslucentLevel: Int = 80 {
        didSet { persist(sidebarTranslucentLevel, .sidebarTranslucentLevel) }
    }

    public var contentTranslucentLevel: Int = 40 {
        didSet { persist(contentTranslucentLevel, .contentTranslucentLevel) }
    }

    public var iconSize: Double = 54.0 {
        didSet { persist(iconSize, .iconSize) }
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
            persist(favoriteURLs.map(\.path), .favoriteURLs)
        }
    }

    /// `private(set)`: mutations must go through the methods below so persistence can't be bypassed.
    /// Populated from disk in `loadSavedPreferences()`, not as a stored-property default (that would
    /// read JSON off disk before `init`'s body even runs).
    public internal(set) var smartFolders: [SmartFolder] = []

    public var navigationMode: NavigationMode = .gnome {
        didSet { persist(navigationMode, .navigationMode) }
    }

    public var isCompactMode: Bool = false {
        didSet { persist(isCompactMode, .isCompactMode) }
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

    /// When off, `viewModeForFolder`/`setViewModeForFolder` just use the single global `viewMode`.
    public var perFolderViewModeEnabled: Bool = false {
        didSet { persist(perFolderViewModeEnabled, .perFolderViewModeEnabled) }
    }

    /// Populated from disk in `loadSavedPreferences()`, not as a stored-property default.
    public var perFolderViewModes: [String: String] = [:] {
        didSet {
            guard perFolderViewModes.count > Self.maxPerFolderViewModes else {
                schedulePerFolderViewModesSave()
                return
            }
            // Trim in a single reassignment so this `didSet` re-enters at most once.
            let evict = Self.keysToEvict(
                current: Set(perFolderViewModes.keys), previous: Set(oldValue.keys), cap: Self.maxPerFolderViewModes)
            var trimmed = perFolderViewModes
            evict.forEach { trimmed.removeValue(forKey: $0) }
            perFolderViewModes = trimmed
        }
    }

    var suppressColumnStatePersistence: Bool = false

    func saveListColumnStates() {
        do {
            let data = try JSONEncoder().encode(listColumnStates)
            UserDefaults.standard.set(data, forKey: DefaultsKey.listColumnStates.rawValue)
        } catch {
            // Encoding failure here silently drops the user's column widths/visibility on next
            // launch (falls back to defaults) with no other signal.
            ErrorReporter.report(error, context: "Encoding list column states for persistence")
        }
    }

    /// Unified slider: getter reports `sidebarTranslucentLevel`; setter deliberately writes BOTH it
    /// and `contentTranslucentLevel`. Adjust the two underlying properties directly if they must differ.
    public var translucentLevel: Int {
        get { sidebarTranslucentLevel }
        set {
            sidebarTranslucentLevel = newValue
            contentTranslucentLevel = newValue
        }
    }

    /// Light mode's window is already brighter, so the translucency overlay is dialed back to
    /// avoid washing content out.
    private static let lightModeOverlayDamping = 0.5

    public var sidebarOverlayOpacity: Double {
        let base = 1.0 - Double(sidebarTranslucentLevel) / 100.0
        return appAppearance == .light ? base * Self.lightModeOverlayDamping : base
    }

    public var contentOverlayOpacity: Double {
        let base = 1.0 - Double(contentTranslucentLevel) / 100.0
        return appAppearance == .light ? base * Self.lightModeOverlayDamping : base
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
        smartFolders = SmartFolderService.loadSavedSmartFolders()
        if let modes = defaults.dictionary(forKey: DefaultsKey.perFolderViewModes.rawValue) as? [String: String] {
            perFolderViewModes = modes
        }
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
        loadEnum(.navigationMode, into: \.navigationMode, from: defaults)
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
