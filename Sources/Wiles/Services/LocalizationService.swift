import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
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

    public var displayName: String {
        switch self {
        case .system: "System Default"
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
