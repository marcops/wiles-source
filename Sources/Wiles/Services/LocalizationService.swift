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

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .portuguese: return "Português"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        case .russian: return "Русский"
        case .swedish: return "Svenska"
        case .turkish: return "Türkçe"
        case .chinese: return "中文"
        case .arabic: return "العربية"
        }
    }
}
