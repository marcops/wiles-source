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

    /// Whether a fresh install shows this column before the user customizes visibility.
    public var isVisibleByDefault: Bool {
        switch self {
        case .name, .size, .dateModified: true
        case .dateCreated, .dateAccessed, .kind, .owner, .group: false
        }
    }

    private static let dateColumnWidth: CGFloat = 160

    /// Default fixed width. `.name` gets a real starting width too, but its column is rendered
    /// with `maxWidth: .infinity` so this value only matters before the user resizes it.
    public var defaultWidth: CGFloat {
        switch self {
        case .name: 280
        case .size: 90
        case .dateModified: Self.dateColumnWidth
        case .dateCreated: Self.dateColumnWidth
        case .dateAccessed: Self.dateColumnWidth
        case .kind: 120
        case .owner: 100
        case .group: 100
        }
    }
}
