import Foundation

public enum SortOption: String, CaseIterable, Identifiable, Hashable, Equatable, Sendable {
    case name = "Name"
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case dateAccessed = "Date Last Opened"
    case size = "Size"
    case kind = "Kind"
    case owner = "Owner"
    case group = "Group"
    public var id: String { rawValue }

    /// Localized label for menu/Settings pickers (the raw values above stay in English since
    /// they're persisted verbatim to `UserDefaults` via `DefaultsKey.sortOption`).
    public var l10nKey: L10n.Key {
        switch self {
        case .name: return .name
        case .dateModified: return .dateModified
        case .dateCreated: return .created
        case .dateAccessed: return .lastOpened
        case .size: return .size
        case .kind: return .kind
        case .owner: return .owner
        case .group: return .group
        }
    }
}
