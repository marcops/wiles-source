import CoreGraphics
import Foundation
import Observation

@Observable
@MainActor
public final class SelectionStore {
    /// Fixed starting point for a Shift+Arrow selection run — must not be derived from
    /// `selectedURLs.first`, since `Set` has no stable order and would make the anchor drift to
    /// an arbitrary already-selected item on every subsequent Shift+Arrow press.
    public var keyboardSelectionAnchorURL: URL?
    /// Output-only signal for the view to scroll into place — the item a keyboard move just
    /// landed on. Never read back into selection math, so it can't reintroduce the staleness
    /// bugs a stored "current cursor" caused there.
    public var lastMovedURL: URL?
    /// Cell frames from the Grid View, updated live. Used to compute the real column count and,
    /// together with `listCellFrames`, to hit-test the drag-to-select marquee. Read only from
    /// SelectionRectangleOverlay's gesture handler (never from a view `body`), so updates here
    /// don't trigger a re-render of FileGridView/FileListView on every newly-visible lazy row.
    public var gridCellFrames: [URL: CGRect] = [:] {
        didSet { cachedGridColumnCount = nil }
    }

    /// Cell frames from the List View — see `gridCellFrames`.
    public var listCellFrames: [URL: CGRect] = [:]
    /// The rendered width of each Grid card's name label while NOT being renamed — captured so the
    /// rename field that replaces it can reuse that exact width instead of guessing/forcing one.
    public var gridLabelWidths: [URL: CGFloat] = [:]

    /// Grid item currently showing its full name after being selected and left alone — same
    /// clipped-cell overlay pattern as `WindowUIState.renameItem`.
    public var revealingFullNameURL: URL?

    /// Set when navigating up/back to a parent directory, so the child folder just left gets reselected instead of the first item.
    public var pendingSelectionURL: URL?

    /// Tolerance for treating two cells' Y origins as "the same row" when counting Grid columns.
    private static let sameRowYTolerance: CGFloat = 5
    private var cachedGridColumnCount: Int?

    /// Actual number of columns currently rendered in Grid View — derived from real cell Y positions.
    /// Cached and invalidated by `gridCellFrames`'s `didSet` since this can be read on every key repeat.
    public var gridColumnCount: Int {
        if let cachedGridColumnCount {
            return cachedGridColumnCount
        }
        let count: Int = if gridCellFrames.count > 1, let firstY = gridCellFrames.values.map(\.origin.y).min() {
            gridCellFrames.values.filter { abs($0.origin.y - firstY) < Self.sameRowYTolerance }.count
        } else {
            1
        }
        cachedGridColumnCount = count
        return count
    }

    public var searchQuery: String = "" {
        didSet {
            guard !isApplyingSilentSearchQuery else { return }
            // `activeFolderID` deliberately stays put: it only drives the sidebar's active-row
            // highlight, which should keep showing the smart folder as selected while its results
            // are on screen, even as the query text is refined — only a real navigation
            // (navigateTo) should move that highlight elsewhere.
            onSearchQueryChanged?()
        }
    }

    private var isApplyingSilentSearchQuery = false

    /// Sets `searchQuery` without firing the refresh handler — for callers (navigation,
    /// smart-folder run) that immediately drive their own reload and don't want a debounced
    /// search refresh racing it.
    public func setSearchQuerySilently(_ value: String) {
        isApplyingSilentSearchQuery = true
        defer { isApplyingSilentSearchQuery = false }
        searchQuery = value
    }

    public var isSearching: Bool = false

    public var selectedURLs: Set<URL> = []

    /// Set by `AppState.init` to `{ [weak self] in self?.refreshCurrentDirectory() }` — lets
    /// `searchQuery`'s `didSet` trigger an `AppState`-level refresh without this store holding a
    /// reference back to `AppState`. Same idiom as `FileSystemStore.startDirectoryMonitoring`'s
    /// `refreshHandler` closure. `private(set)`: only `AppState`'s own init may install this wiring —
    /// a `public var` let any view silently overwrite it and kill refresh-on-search.
    public private(set) var onSearchQueryChanged: (() -> Void)?

    public init() { }

    /// Installs the refresh-on-search-change wiring. Called once, from `AppState.init`.
    public func setSearchQueryHandler(_ handler: @escaping () -> Void) {
        onSearchQueryChanged = handler
    }
}
