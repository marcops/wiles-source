import SwiftUI

public enum AppAppearance: String, CaseIterable, Identifiable, Hashable, Equatable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String {
        rawValue
    }

    /// Localized label for the Settings/menu appearance picker (the raw values above stay in
    /// English since they're persisted verbatim to `UserDefaults` via `DefaultsKey.appAppearance`).
    public var l10nKey: L10n.Key {
        switch self {
        case .system: .appearanceSystemOption
        case .light: .appearanceLightOption
        case .dark: .appearanceDarkOption
        }
    }
}
