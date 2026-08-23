import Foundation

public enum NavigationMode: String, CaseIterable, Identifiable, Sendable {
    case gnome
    case macOS

    /// Accepts the old English-sentence raw values (persisted verbatim by earlier app versions)
    /// alongside the stable slugs, so an existing saved preference isn't silently reset.
    public init?(rawValue: String) {
        switch rawValue {
        case "gnome", "GNOME Mode (Enter to Open, F2 to Rename)": self = .gnome
        case "macOS", "macOS Mode (Cmd+Down to Open, Enter to Rename)": self = .macOS
        default: return nil
        }
    }

    public var id: String {
        rawValue
    }

    /// Localized, compact label for menu/Settings pickers (the raw values above stay in English
    /// since they're persisted verbatim to `UserDefaults` via `DefaultsKey.navigationMode`).
    public var l10nKey: L10n.Key {
        switch self {
        case .gnome: .gnomeModeTitle
        case .macOS: .macModeTitle
        }
    }
}
