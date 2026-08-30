import Foundation

/// The user's answer to a move name-collision prompt (Replace / Keep Both / Cancel).
public struct MoveCollisionChoice: Sendable {
    public enum Action: Sendable {
        case replace
        case keepBoth
        case cancel

        /// The service-level `MoveCollisionPolicy` this choice maps to. `nil` for `.cancel`, which
        /// is a UI-flow outcome the caller resolves before any move is attempted — the service
        /// never sees it. Keeps the one `Action`→`Policy` mapping here instead of an inline `? :`.
        public var policy: MoveCollisionPolicy? {
            switch self {
            case .replace: .replace
            case .keepBoth: .keepBoth
            case .cancel: nil
            }
        }
    }

    public let action: Action
    /// When true, apply `action` to every remaining collision in the same batch without re-asking.
    public let applyToAll: Bool
}
