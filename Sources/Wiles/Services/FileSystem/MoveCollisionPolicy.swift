import Foundation

/// How `FileSystemService.moveItem` resolves a destination that already has an item of the same
/// name. Never a silent `replaceItem` — the caller must pick one of these explicitly.
public enum MoveCollisionPolicy: Sendable {
    /// Throw `WilesError.destinationExists(name:)` and touch nothing (default).
    case failIfExists
    /// Move to a free name (` 2`, ` 3`, …) via `uniqueDestination`, like `copyItem`.
    case keepBoth
    /// Send the existing destination to Trash (recoverable), then move the source into its place.
    case replace
}
