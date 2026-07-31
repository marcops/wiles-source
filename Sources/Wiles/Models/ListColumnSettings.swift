import Foundation
import CoreGraphics

// MARK: - Column Identity

public enum ListColumn: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case name         = "Name"
    case size         = "Size"
    case dateModified = "Date Modified"
    case dateCreated  = "Date Created"
    case dateAccessed = "Date Last Opened"
    case kind         = "Kind"
    case owner        = "Owner"
    case group        = "Group"

    public var id: String { rawValue }

    /// Name column always fills remaining space and cannot be hidden.
    public var isAlwaysVisible: Bool { self == .name }

    /// Default fixed width. Name returns 0 — it uses maxWidth: .infinity instead.
    public var defaultWidth: CGFloat {
        switch self {
        case .name:         return 280
        case .size:         return 90
        case .dateModified: return 160
        case .dateCreated:  return 160
        case .dateAccessed: return 160
        case .kind:         return 120
        case .owner:        return 100
        case .group:        return 100
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
        let initialVisible: Set<ListColumn> = [.name, .size, .dateModified, .kind]
        return ListColumn.allCases.map { col in
            ListColumnState(column: col, width: col.defaultWidth, isVisible: initialVisible.contains(col))
        }
    }
}
