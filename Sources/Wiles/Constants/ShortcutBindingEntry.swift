import Foundation

/// One row of `ViewPreferences.activeShortcuts` — the live combo currently bound to a
/// `ShortcutRegistry.Command`, persisted as an array (not a `Codable` dictionary keyed by an enum,
/// no precedent for that shape in this codebase — see `ListColumnState`).
public struct ShortcutBindingEntry: Codable, Equatable, Sendable {
    public var command: ShortcutRegistry.Command
    public var binding: ShortcutBinding

    public init(command: ShortcutRegistry.Command, binding: ShortcutBinding) {
        self.command = command
        self.binding = binding
    }
}
