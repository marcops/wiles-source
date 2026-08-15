import CoreGraphics
import Foundation
import Observation

@Observable
@MainActor
public final class SelectionStore {
    /// Bumped by the right-arrow key handler so Column View can drill into the selected item's column.
    public var columnViewDrillRightTrigger: Int = 0
    /// Set alongside `columnViewVerticalTrigger` so Column View moves selection within its active column.
    public var columnViewVerticalDirection: Int = 0
    public var columnViewVerticalTrigger: Int = 0
    /// Bumped by the left-arrow key handler so Column View shifts focus back one column.
    public var columnViewMoveLeftTrigger: Int = 0
    /// Set alongside `columnViewVerticalTrigger` so Column View knows whether to extend the range.
    public var columnViewVerticalIsShift: Bool = false
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
    public var gridCellFrames: [URL: CGRect] = [:]
    /// Cell frames from the List View — see `gridCellFrames`.
    public var listCellFrames: [URL: CGRect] = [:]
    /// The rendered width of each Grid card's name label while NOT being renamed — captured so the
    /// rename field that replaces it can reuse that exact width instead of guessing/forcing one.
    public var gridLabelWidths: [URL: CGFloat] = [:]

    /// Set when navigating up/back to a parent directory, so the child folder just left gets reselected instead of the first item.
    public var pendingSelectionURL: URL?

    /// Actual number of columns currently rendered in Grid View — derived from real cell Y positions.
    public var gridColumnCount: Int {
        guard gridCellFrames.count > 1 else { return 1 }
        let ys = gridCellFrames.values.map(\.origin.y)
        guard let firstY = ys.min() else { return 1 }
        return ys.filter { abs($0 - firstY) < 5 }.count
    }

    public init() { }
}
