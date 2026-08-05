import Foundation
import CoreGraphics
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
    /// Cell frames from the Grid View, updated live. Used to compute the real column count.
    public var gridCellFrames: [URL: CGRect] = [:]

    /// Set when navigating up/back to a parent directory, so the child folder just left gets reselected instead of the first item.
    public var pendingSelectionURL: URL?

    /// Actual number of columns currently rendered in Grid View — derived from real cell Y positions.
    public var gridColumnCount: Int {
        guard gridCellFrames.count > 1 else { return 1 }
        let ys = gridCellFrames.values.map { $0.origin.y }
        guard let firstY = ys.min() else { return 1 }
        return ys.filter { abs($0 - firstY) < 5 }.count
    }

    public init() {}
}
