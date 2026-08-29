import Foundation

/// Result of moving one item in a batch that resolves name collisions interactively.
enum BatchMoveOutcome {
    /// `displacedExisting` is true only for a Replace, where the old file went to Trash and the
    /// caller must not record an undo step for this iteration.
    case moved(to: URL, displacedExisting: Bool)
    case skipped
    /// The user picked Cancel (or a sticky "apply to all → Cancel") — stop the whole batch.
    case cancelled
}
