import Foundation

public enum SymlinkMode: String, CaseIterable, Identifiable, Sendable {
    case absolute = "Absolute"
    case relative = "Relative"
    public var id: String { rawValue }
}
