import Foundation

public enum SymlinkMode: String, CaseIterable, Identifiable, Sendable {
    case absolute = "Absolute"
    case relative = "Relative"
    public var id: String {
        rawValue
    }

    /// Localized picker label — `rawValue` stays fixed English since it's used as `SymlinkService`'s
    /// internal mode identifier, not shown directly to the user.
    public var l10nKey: L10n.Key {
        switch self {
        case .absolute: .symlinkModeAbsolute
        case .relative: .symlinkModeRelative
        }
    }
}
