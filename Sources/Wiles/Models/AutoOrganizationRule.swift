import Foundation

public struct AutoOrganizationRule: Codable, Identifiable, Hashable {
    public var id: UUID
    public var sourceURL: URL
    public var destinationURL: URL
    public var conditionType: RuleConditionType
    public var conditionValue: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), sourceURL: URL, destinationURL: URL, conditionType: RuleConditionType, conditionValue: String, isEnabled: Bool = true) {
        self.id = id
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.conditionType = conditionType
        self.conditionValue = conditionValue
        self.isEnabled = isEnabled
    }
}
