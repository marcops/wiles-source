import Foundation

/// The user's answer to a move name-collision prompt (Replace / Keep Both / Cancel).
public struct MoveCollisionChoice: Sendable {
    public enum Action: Sendable {
        case replace
        case keepBoth
        case cancel
    }

    public let action: Action
    /// When true, apply `action` to every remaining collision in the same batch without re-asking.
    public let applyToAll: Bool
}
