import Foundation

/// One target-name collision found by `BatchRenameService.validateTargets` before any rename runs.
public struct BatchRenameConflict: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Two or more items in the batch compute to this same target name.
        case duplicateWithinBatch
        /// A file already exists at this target name on disk and isn't itself being renamed away.
        case existsOnDisk
    }

    public let targetName: String
    public let kind: Kind

    public init(targetName: String, kind: Kind) {
        self.targetName = targetName
        self.kind = kind
    }
}
