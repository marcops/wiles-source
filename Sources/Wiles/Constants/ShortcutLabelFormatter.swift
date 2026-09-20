import SwiftUI

/// Renders a captured `(character, modifiers)` combo as the same "⌘ ⇧ K"-style label
/// `ShortcutRegistry`'s static table hand-types, so a custom binding reads identically everywhere
/// (Settings row, Help cheat sheet, context-menu hints).
enum ShortcutLabelFormatter {
    static func label(character: String, modifiers: EventModifiers) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        parts.append(symbol(for: character))
        return parts.joined(separator: " ")
    }

    /// AppKit's `charactersIgnoringModifiers` reproduces the same private-use-area code points
    /// `KeyEquivalent`'s own static members (`.delete`, `.escape`, `.upArrow`, …) wrap, so a
    /// captured non-printing key round-trips through here without needing its own capture-time
    /// special-casing.
    private static func symbol(for character: String) -> String {
        guard let scalar = character.unicodeScalars.first else { return character.uppercased() }
        switch scalar {
        case " ": return "Space"
        case "\t": return "Tab"
        case "\r", "\u{3}": return "Return"
        case "\u{1B}": return "Esc"
        case "\u{7F}": return "Delete"
        case "\u{F728}": return "Fwd Delete"
        case "\u{F700}": return "↑"
        case "\u{F701}": return "↓"
        case "\u{F702}": return "←"
        case "\u{F703}": return "→"
        case "\u{F704}" ... "\u{F70F}":
            return "F\(scalar.value - 0xF704 + 1)"
        default:
            return character.uppercased()
        }
    }
}
