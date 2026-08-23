import Foundation

public enum RuleConditionType: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case extensionEquals
    case nameContains
    case namePrefix

    /// Accepts the old English-label raw values (persisted verbatim by earlier app versions,
    /// JSON-encoded into `UserDefaults` via `AutoOrganizationRuleStore`) alongside the stable
    /// slugs, so existing saved rules don't fail to decode.
    public init?(rawValue: String) {
        switch rawValue {
        case "extensionEquals", "Extension Equals": self = .extensionEquals
        case "nameContains", "Name Contains": self = .nameContains
        case "namePrefix", "Name Starts With": self = .namePrefix
        default: return nil
        }
    }

    public var id: String {
        rawValue
    }

    public var l10nKey: L10n.Key {
        switch self {
        case .extensionEquals: .ruleConditionExtensionEquals
        case .nameContains: .ruleConditionNameContains
        case .namePrefix: .ruleConditionNamePrefix
        }
    }
}
