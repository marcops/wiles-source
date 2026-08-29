import Foundation

public struct AutoOrganizationRule: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var sourceURL: URL
    public var destinationURL: URL
    public var conditionType: RuleConditionType
    public var conditionValue: String
    public var isEnabled: Bool
    public var lastTriggeredAt: Date?
    public var totalMovedCount: Int

    public init(
        id: UUID = UUID(), sourceURL: URL, destinationURL: URL, conditionType: RuleConditionType, conditionValue: String, isEnabled: Bool = true,
        lastTriggeredAt: Date? = nil, totalMovedCount: Int = 0) {
        self.id = id
        // Standardized only; symlink resolution is deferred to `isSelfReferential` to keep init I/O-free.
        self.sourceURL = sourceURL.standardizedFileURL
        self.destinationURL = destinationURL.standardizedFileURL
        self.conditionType = conditionType
        self.conditionValue = conditionValue
        self.isEnabled = isEnabled
        self.lastTriggeredAt = lastTriggeredAt
        self.totalMovedCount = totalMovedCount
    }

    /// True when the rule moves files into the same folder it reads from (symlinks resolved here, not at init).
    public var isSelfReferential: Bool {
        sourceURL.resolvingSymlinksInPath() == destinationURL.resolvingSymlinksInPath()
    }

    /// Custom so a rule decoded from persisted JSON also gets its URLs normalized — the
    /// memberwise `init` above only covers newly constructed rules.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL).standardizedFileURL
        destinationURL = try container.decode(URL.self, forKey: .destinationURL).standardizedFileURL
        conditionType = try container.decode(RuleConditionType.self, forKey: .conditionType)
        conditionValue = try container.decode(String.self, forKey: .conditionValue)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        // Both fields were added later; a rule persisted by an earlier app version won't have
        // them in its JSON, so fall back to "never triggered" rather than failing to decode.
        lastTriggeredAt = try container.decodeIfPresent(Date.self, forKey: .lastTriggeredAt)
        totalMovedCount = try container.decodeIfPresent(Int.self, forKey: .totalMovedCount) ?? 0
    }
}
