import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case english = "en"
    case portuguese = "pt"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case dutch = "nl"
    case polish = "pl"
    case russian = "ru"
    case swedish = "sv"
    case turkish = "tr"
    case chinese = "zh-Hans"
    case arabic = "ar"

    public var id: String {
        rawValue
    }

    /// Picker label. `.system` is the only real UI string — localized into `uiLanguage` (defaults
    /// to the OS language). Every other case is a language endonym, identical in every locale.
    public func displayName(in uiLanguage: Self = .system) -> String {
        self == .system ? L10n.string(.languageSystemDefault, lang: uiLanguage) : endonym
    }

    /// The language's name in its own language — shown identically in every locale.
    private var endonym: String {
        switch self {
        case .system: ""
        case .english: "English"
        case .portuguese: "Português"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .dutch: "Nederlands"
        case .polish: "Polski"
        case .russian: "Русский"
        case .swedish: "Svenska"
        case .turkish: "Türkçe"
        case .chinese: "中文"
        case .arabic: "العربية"
        }
    }
}
