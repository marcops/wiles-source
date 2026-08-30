import Foundation

/// Result of moving one item in a batch that resolves name collisions interactively.
enum BatchMoveOutcome {
    /// `displacedTrashedURL` is set when a Replace sent an existing file to the Trash — the caller
    /// records a `.trash` undo step for it so `⌘Z` restores it before undoing the move itself.
    case moved(to: URL, displacedExisting: Bool, displacedTrashedURL: URL?)
    case skipped
    /// The user picked Cancel (or a sticky "apply to all → Cancel") — stop the whole batch.
    case cancelled
}
