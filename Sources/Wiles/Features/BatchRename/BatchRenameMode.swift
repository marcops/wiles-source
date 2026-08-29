import Foundation

public enum BatchRenameMode: Sendable, Equatable {
    case replace(find: String, replaceWith: String)
    case addPrefixSuffix(prefix: String, suffix: String)
    case sequenceNumber(prefix: String, startNumber: Int, paddingDigits: Int)
    case regex(pattern: String, template: String)
}
