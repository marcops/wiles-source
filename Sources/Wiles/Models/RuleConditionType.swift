import Foundation

public enum RuleConditionType: String, Codable, CaseIterable, Identifiable {
    case extensionEquals = "Extension Equals"
    case nameContains = "Name Contains"
    case namePrefix = "Name Starts With"

    public var id: String {
        rawValue
    }
}
