import Foundation

public enum NavigationMode: String, CaseIterable, Identifiable, Sendable {
    case windows
    case macOS
    case custom

    /// Accepts the old English-sentence raw values and the pre-rename "gnome" slug (persisted
    /// verbatim by earlier app versions) alongside the current one, so an existing saved
    /// preference isn't silently reset.
    public init?(rawValue: String) {
        switch rawValue {
        case "windows", "gnome", "GNOME Mode (Enter to Open, F2 to Rename)": self = .windows
        case "macOS", "macOS Mode (Cmd+Down to Open, Enter to Rename)": self = .macOS
        case "custom": self = .custom
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
        case .windows: .windowsModeTitle
        case .macOS: .macModeTitle
        case .custom: .customModeTitle
        }
    }
}
