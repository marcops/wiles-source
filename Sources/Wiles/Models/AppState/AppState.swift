import GitBeacon
import Observation
import SwiftUI

/// `@MainActor` makes this implicitly `Sendable`. Background file work runs in `Task { @MainActor }`
/// awaiting a `nonisolated` op, so no closure captures `self` and only `Sendable` values cross back.
@Observable
@MainActor
public final class AppState {
    // MARK: - Domain Stores

    // `var`, not `let`: SwiftUI's `$appState.preferences.someField`-style two-way bindings (used
    // throughout Views/) only compose into a `ReferenceWritableKeyPath` when every intermediate
    // stored property in the chain is mutable — even though `preferences` itself is a class and
    // nothing here actually reassigns it, `let` breaks every such binding across the app.
    public var navigation: NavigationStore
    public var preferences: PreferencesStore
    public var modal: ModalStore
    public var selection: SelectionStore
    public var fileSystem: FileSystemStore
    public var smartFolder: SmartFolderStore
    public var transient: TransientStore
    /// Per-window undo/redo history — each `AppState` (constructed fresh per window) gets its own,
    /// so ⌘Z in one window never undoes an action performed in a different window.
    public let undoRedoService = UndoRedoService()

    /// Per-window smart-folder query runner. NOT `.shared`: its in-flight `SpotlightQuery` +
    /// staleness token are per-run session state, and a shared instance meant one window's smart
    /// folder discarded its own results when another window ran its own query.
    public let smartFolderService = SmartFolderService()

    /// Per-window (not `.shared`): their live session state — an mDNS browser, a bound listener —
    /// must not be torn down by another window's view lifecycle.
    public let networkDiscoveryService = NetworkDiscoveryService()
    public let httpServerService = LocalHttpServerService()

    /// Per-window (not `.shared`): `activeTasks` is this window's in-flight copy/move/delete
    /// progress — a shared instance leaked it into every other window's footer/popover.
    public let backgroundOperations = BackgroundOperationsService()

    /// Per-window thumbnail prefetch session. The `ThumbnailService.shared` cache stays shared; only
    /// the "which folder am I prefetching" task is per-window, so two windows don't cancel each
    /// other's prefetch continuously.
    public let thumbnailPrefetcher = ThumbnailPrefetcher()

    /// `nonisolated`: a plain constant URL, safe from any context — lets `FileSystemService`
    /// (off-`@MainActor`) reference it directly instead of duplicating the path as a literal.
    public nonisolated static let recentsVirtualURL = URL(fileURLWithPath: "/virtual/recents")

    /// Debounces the refresh triggered by `searchQuery` edits — without it, every keystroke
    /// (and every key-repeat tick) restarts a directory load, and with "search everywhere" on,
    /// a full recursive crawl of `~`. Cancelled by any explicit `refreshCurrentDirectory()`.
    var searchDebounceTask: Task<Void, Never>?
    static let searchDebounceInterval: Duration = .milliseconds(250)

    public init(preferences: PreferencesStore = PreferencesStore(), modal: ModalStore = ModalStore(), transient: TransientStore = TransientStore()) {
        navigation = NavigationStore()
        self.preferences = preferences
        self.modal = modal
        selection = SelectionStore()
        fileSystem = FileSystemStore()
        smartFolder = SmartFolderStore()
        self.transient = transient

        selection.setSearchQueryHandler { [weak self] in self?.scheduleSearchRefresh() }
        navigation.onVolumeUnreachable = { [weak self] fallback in self?.navigateTo(fallback) }
        undoRedoService.onFileRelocated = { [weak self] from, to in self?.remapRelocatedState(from: from, to: to) }
        undoRedoService.onRestoreDiverged = { [weak self] intended, actual in
            guard let self else { return }
            showError(WilesError.localized(key: .undoRestoredDifferentName, arguments: [actual, intended]))
        }
    }
}
