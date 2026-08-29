import Foundation
import GitBeacon
import Observation

/// Content-area view preferences: view mode (grid/list), sort, hidden files, navigation mode,
/// icon size, list column state, per-folder view modes, the terminal drawer / trailing inspector
/// defaults for a new window, and related toggles. Split out of `PreferencesStore` (SRP).
@Observable
@MainActor
public final class ViewPreferences: PersistablePreferenceStore {
    public var viewMode: ViewMode = .grid {
        didSet { persist(viewMode, .viewMode) }
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

    public var navigationMode: NavigationMode = .gnome {
        didSet { persist(navigationMode, .navigationMode) }
    }

    public var isCompactMode: Bool = false {
        didSet { persist(isCompactMode, .isCompactMode) }
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

    /// Persisted default trailing inspector for a *new* window — see `sidebarWidth` above.
    public var trailingInspector: TrailingInspector = .none {
        didSet { persist(trailingInspector, .trailingInspector) }
    }

    public var skipDeleteConfirmation: Bool = false {
        didSet { persist(skipDeleteConfirmation, .skipDeleteConfirmation) }
    }

    /// Persistence is debounced: the footer's size slider drives this every frame of a drag, and
    /// an un-debounced `didSet` would do a synchronous `UserDefaults` write per frame.
    public var iconSize: Double = 54.0 {
        didSet { scheduleIconSizeSave() }
    }

    /// When off, `AppState.viewModeForFolder` just uses the single global `viewMode`.
    public var perFolderViewModeEnabled: Bool = false {
        didSet { persist(perFolderViewModeEnabled, .perFolderViewModeEnabled) }
    }

    /// Populated from disk in `init`, not as a stored-property default.
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

    private var suppressColumnStatePersistence: Bool = false

    /// Caps `perFolderViewModes` for the same reason as `SidebarPreferences.expandedTreePaths`.
    private static let maxPerFolderViewModes = 500
    private static let perFolderViewModesSaveDebounceInterval: TimeInterval = 0.5
    private var pendingPerFolderViewModesSave: DispatchWorkItem?

    private static let iconSizeSaveDebounceInterval: TimeInterval = 0.3
    private var pendingIconSizeSave: DispatchWorkItem?

    private static let columnStatesSaveDebounceInterval: TimeInterval = 0.3
    private var pendingColumnStatesSave: DispatchWorkItem?

    public init() {
        let defaults = UserDefaults.standard
        if let modes = defaults.dictionary(forKey: DefaultsKey.perFolderViewModes.rawValue) as? [String: String] {
            perFolderViewModes = modes
        }
        loadEnum(.viewMode, into: \.viewMode, from: defaults)
        loadEnum(.navigationMode, into: \.navigationMode, from: defaults)
        loadEnum(.sortOption, into: \.sortOption, from: defaults)
        loadBool(.sortAscending, into: \.sortAscending, from: defaults)
        loadBool(.showHiddenFiles, into: \.showHiddenFiles, from: defaults)
        loadBool(.isCompactMode, into: \.isCompactMode, from: defaults)
        loadBool(.perFolderViewModeEnabled, into: \.perFolderViewModeEnabled, from: defaults)
        loadBool(.middleTruncateNames, into: \.middleTruncateNames, from: defaults)
        loadBool(.alwaysShowFullPathBar, into: \.alwaysShowFullPathBar, from: defaults)
        loadBool(.showFooter, into: \.showFooter, from: defaults)
        loadBool(.showTerminalDrawer, into: \.showTerminalDrawer, from: defaults)
        loadBool(.skipDeleteConfirmation, into: \.skipDeleteConfirmation, from: defaults)
        loadTrailingInspector(defaults)
        loadListColumnStates(defaults)

        let width = defaults.double(forKey: DefaultsKey.sidebarWidth.rawValue)
        if width > 0 {
            sidebarWidth = width
        }
        loadBool(.isSidebarCollapsed, into: \.isSidebarCollapsed, from: defaults)

        let iSize = defaults.double(forKey: DefaultsKey.iconSize.rawValue)
        if iSize >= IconSizeToken.minSize, iSize <= IconSizeToken.maxSize {
            iconSize = iSize
        }
    }

    /// Applies `body` with `listColumnStates` persistence held off, restoring the prior state on exit
    /// (via `defer`, so an early return or throw inside `body` can't leave persistence stuck off).
    func withColumnStatePersistenceSuppressed(_ body: () -> Void) {
        let previous = suppressColumnStatePersistence
        suppressColumnStatePersistence = true
        defer { suppressColumnStatePersistence = previous }
        body()
    }

    /// Coalesces a window-resize's worth of name-column-width updates (applied with
    /// `persist: false`) into a single encode + write once the resize settles. `saveListColumnStates()`
    /// itself stays synchronous for the drag-end / explicit callers.
    func scheduleListColumnStatesSave() {
        pendingColumnStatesSave?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.saveListColumnStates() }
        pendingColumnStatesSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.columnStatesSaveDebounceInterval, execute: workItem)
    }

    func saveListColumnStates() {
        pendingColumnStatesSave?.cancel()
        do {
            let data = try JSONEncoder().encode(listColumnStates)
            UserDefaults.standard.set(data, forKey: DefaultsKey.listColumnStates.rawValue)
        } catch {
            // Encoding failure here silently drops the user's column widths/visibility on next
            // launch (falls back to defaults) with no other signal.
            ErrorReporter.report(error, context: "Encoding list column states for persistence")
        }
    }

    /// Restores `trailingInspector`, falling back to the pre-enum `wiles_showPreviewSidebar` /
    /// `wiles_showDiskUsageSidebar` bools so an upgrade doesn't lose the open inspector.
    private func loadTrailingInspector(_ defaults: UserDefaults) {
        if let raw = defaults.string(forKey: DefaultsKey.trailingInspector.rawValue), let value = TrailingInspector(rawValue: raw) {
            trailingInspector = value
        } else if defaults.bool(forKey: "wiles_showPreviewSidebar") {
            trailingInspector = .preview
        } else if defaults.bool(forKey: "wiles_showDiskUsageSidebar") {
            trailingInspector = .diskUsage
        }
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

    /// Coalesces a drag's worth of `iconSize` changes into one `UserDefaults` write once the
    /// slider settles.
    private func scheduleIconSizeSave() {
        pendingIconSizeSave?.cancel()
        let value = iconSize
        let workItem = DispatchWorkItem {
            UserDefaults.standard.set(value, forKey: DefaultsKey.iconSize.rawValue)
        }
        pendingIconSizeSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.iconSizeSaveDebounceInterval, execute: workItem)
    }

    /// Coalesces repeated `perFolderViewModes` edits into one `UserDefaults` write.
    private func schedulePerFolderViewModesSave() {
        pendingPerFolderViewModesSave?.cancel()
        let modes = perFolderViewModes
        let workItem = DispatchWorkItem {
            UserDefaults.standard.set(modes, forKey: DefaultsKey.perFolderViewModes.rawValue)
        }
        pendingPerFolderViewModesSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.perFolderViewModesSaveDebounceInterval, execute: workItem)
    }
}
