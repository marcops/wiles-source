import Foundation

public enum NavigationMode: String, CaseIterable, Identifiable, Sendable {
    case gnome = "GNOME Mode (Enter to Open, F2 to Rename)"
    case macOS = "macOS Mode (Cmd+Down to Open, Enter to Rename)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .gnome: return "Windows Mode"
        case .macOS: return "macOS Mode"
        }
    }

    /// Localized, compact label for menu/Settings pickers (the raw values above stay in English
    /// since they're persisted verbatim to `UserDefaults` via `DefaultsKey.navigationMode`).
    public var l10nKey: L10n.Key {
        switch self {
        case .gnome: return .gnomeModeTitle
        case .macOS: return .macModeTitle
        }
    }
}
