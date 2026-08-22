import CoreGraphics
import Foundation

// MARK: - Column Identity

public enum ListColumn: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case name = "Name"
    case size = "Size"
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case dateAccessed = "Date Last Opened"
    case kind = "Kind"
    case owner = "Owner"
    case group = "Group"

    public var id: String {
        rawValue
    }

    /// Name column always fills remaining space and cannot be hidden.
    public var isAlwaysVisible: Bool {
        self == .name
    }

    /// Default fixed width. Name returns 0 — it uses maxWidth: .infinity instead.
    public var defaultWidth: CGFloat {
        switch self {
        case .name: 280
        case .size: 90
        case .dateModified: 160
        case .dateCreated: 160
        case .dateAccessed: 160
        case .kind: 120
        case .owner: 100
        case .group: 100
        }
    }
}
