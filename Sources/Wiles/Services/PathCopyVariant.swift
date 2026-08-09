import Foundation

public enum PathCopyVariant: String, CaseIterable, Sendable {
    case absolute
    case relative
    case fileURL
    case terminalEscaped
}
