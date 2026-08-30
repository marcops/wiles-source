import Foundation
import Observation

/// Sidebar preferences: which sections are shown, which are expanded, and the set of expanded
/// directory-tree folder paths. Split out of `PreferencesStore` (SRP). The "should this section
/// actually render" gates (which also depend on favorites/smart-folders data) live on `AppState`
/// as `showsXSection` / `hasVisibleSidebarContent`, the one cross-store source of truth.
@Observable
@MainActor
public final class SidebarPreferences: PersistablePreferenceStore {
    @ObservationIgnored var isRestoringDefaults = false

    public var showDirectoryTree: Bool = false {
        didSet { guard !isRestoringDefaults else { return }; persist(showDirectoryTree, .showDirectoryTree) }
    }

    public var showFavorites: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(showFavorites, .showFavorites) }
    }

    public var showRecents: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(showRecents, .showRecents) }
    }

    public var showPlaces: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(showPlaces, .showPlaces) }
    }

    public var showNetworkAndCloud: Bool = false {
        didSet { guard !isRestoringDefaults else { return }; persist(showNetworkAndCloud, .showNetworkAndCloud) }
    }

    public var showSidebarSectionTitles: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(showSidebarSectionTitles, .showSidebarSectionTitles) }
    }

    public var showTags: Bool = false {
        didSet { guard !isRestoringDefaults else { return }; persist(showTags, .showTags) }
    }

    public var isFavoritesExpanded: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(isFavoritesExpanded, .isFavoritesExpanded) }
    }

    public var isMacExpanded: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(isMacExpanded, .isMacExpanded) }
    }

    public var isNetworkExpanded: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(isNetworkExpanded, .isNetworkExpanded) }
    }

    public var isRecentsExpanded: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(isRecentsExpanded, .isRecentsExpanded) }
    }

    public var isDevicesExpanded: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(isDevicesExpanded, .isDevicesExpanded) }
    }

    public var isTreeExpanded: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(isTreeExpanded, .isTreeExpanded) }
    }

    public var isTagsExpanded: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(isTagsExpanded, .isTagsExpanded) }
    }

    public var isSmartFoldersExpanded: Bool = true {
        didSet { guard !isRestoringDefaults else { return }; persist(isSmartFoldersExpanded, .isSmartFoldersExpanded) }
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

    /// Caps `expandedTreePaths` so an unbounded set of ever-expanded folders isn't retained forever.
    private static let maxExpandedTreePaths = 500
    /// Coalesces rapid expand/collapse toggles into a single `UserDefaults` write.
    private static let expandedTreePathsSaveDebounceInterval: TimeInterval = 0.5
    private var pendingExpandedTreePathsSave: DispatchWorkItem?

    public init() {
        let defaults = UserDefaults.standard
        loadBool(.showDirectoryTree, into: \.showDirectoryTree, from: defaults)
        loadBool(.showFavorites, into: \.showFavorites, from: defaults)
        loadBool(.showRecents, into: \.showRecents, from: defaults)
        loadBool(.showPlaces, into: \.showPlaces, from: defaults)
        loadBool(.showNetworkAndCloud, into: \.showNetworkAndCloud, from: defaults)
        loadBool(.showSidebarSectionTitles, into: \.showSidebarSectionTitles, from: defaults)
        loadBool(.showTags, into: \.showTags, from: defaults)
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
}
