import CoreGraphics
import Foundation

// MARK: - Per-Column Persisted State

public struct ListColumnState: Codable, Sendable {
    public var column: ListColumn
    public var width: CGFloat
    public var isVisible: Bool

    public init(column: ListColumn, width: CGFloat, isVisible: Bool) {
        self.column = column
        self.width = width
        self.isVisible = isVisible
    }
}

// MARK: - Default Set

extension ListColumnState {
    static func defaults() -> [ListColumnState] {
        ListColumn.allCases.map { col in
            ListColumnState(column: col, width: col.defaultWidth, isVisible: col.isVisibleByDefault)
        }
    }
}
