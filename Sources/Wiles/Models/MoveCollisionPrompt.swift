import Foundation

/// A pending "an item named X already exists" decision, presented per-window as a sheet by
/// `MoveCollisionSheet`. `resolve` hands the choice back to the awaiting move loop — see
/// `WindowUIState.promptMoveCollision`.
@MainActor
final class MoveCollisionPrompt: Identifiable {
    let id = UUID()
    let itemName: String
    /// Show the "Apply to all" checkbox — only when more than one collision may still occur in the batch.
    let showApplyToAll: Bool
    let resolve: (MoveCollisionChoice) -> Void

    init(itemName: String, showApplyToAll: Bool, resolve: @escaping (MoveCollisionChoice) -> Void) {
        self.itemName = itemName
        self.showApplyToAll = showApplyToAll
        self.resolve = resolve
    }
}
