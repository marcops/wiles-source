import SwiftUI

/// A single user-captured key combination for Custom shortcut mode — recorded from one `NSEvent`
/// keyDown, carrying both representations `ShortcutRegistry` needs: a character-based
/// `KeyEquivalent` for SwiftUI menu items, and the raw hardware `physicalKeyCode` for
/// `GlobalKeyMonitor`'s monitor-only dispatch paths.
public struct ShortcutBinding: Codable, Equatable, Sendable {
    public var character: String
    public var modifiersRawValue: Int
    public var physicalKeyCode: UInt16?

    public init(character: String, modifiers: EventModifiers, physicalKeyCode: UInt16?) {
        self.character = character
        modifiersRawValue = modifiers.rawValue
        self.physicalKeyCode = physicalKeyCode
    }

    public var modifiers: EventModifiers {
        EventModifiers(rawValue: modifiersRawValue)
    }

    public var keyEquivalent: KeyEquivalent? {
        character.first.map { KeyEquivalent($0) }
    }
}
