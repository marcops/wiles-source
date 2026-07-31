import Foundation
import CoreGraphics

// MARK: - Column Identity

public enum ListColumn: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case name         = "Name"
    case size         = "Size"
    case dateModified = "Date Modified"
    case kind         = "Kind"

    public var id: String { rawValue }

    /// Name column always fills remaining space and cannot be hidden.
    public var isAlwaysVisible: Bool { self == .name }

    /// Default fixed width. Name returns 0 — it uses maxWidth: .infinity instead.
    public var defaultWidth: CGFloat {
        switch self {
        case .name:         return 0
        case .size:         return 90
        case .dateModified: return 160
        case .kind:         return 90
        }
    }
}

// MARK: - Per-Column Persisted State

public struct ListColumnState: Codable, Sendable {
    public var column: ListColumn
    public var width: CGFloat
    public var isVisible: Bool

    public init(column: ListColumn, width: CGFloat, isVisible: Bool) {
        self.column    = column
        self.width     = width
        self.isVisible = isVisible
    }
}

// MARK: - Default Set

extension ListColumnState {
    static func defaults() -> [ListColumnState] {
        ListColumn.allCases.map { col in
            ListColumnState(column: col, width: col.defaultWidth, isVisible: true)
        }
    }
}
