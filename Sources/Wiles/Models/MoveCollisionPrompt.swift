import Foundation

/// A pending "an item named X already exists" decision, presented per-window as a sheet by
/// `MoveCollisionSheet`. `resolve` hands the choice back to the awaiting move loop — see
/// `WindowUIState.promptMoveCollision`. Idempotent: only the first `resolve` call takes effect,
/// so the sheet's normal dismissal and an abrupt window teardown can both call it without
/// double-resuming the continuation.
@MainActor
final class MoveCollisionPrompt: Identifiable {
    let id = UUID()
    let itemName: String
    /// Show the "Apply to all" checkbox — only when more than one collision may still occur in the batch.
    let showApplyToAll: Bool
    private let onResolve: (MoveCollisionChoice) -> Void
    private var resolved = false

    init(itemName: String, showApplyToAll: Bool, onResolve: @escaping (MoveCollisionChoice) -> Void) {
        self.itemName = itemName
        self.showApplyToAll = showApplyToAll
        self.onResolve = onResolve
    }

    func resolve(_ choice: MoveCollisionChoice) {
        guard !resolved else { return }
        resolved = true
        onResolve(choice)
    }
}
