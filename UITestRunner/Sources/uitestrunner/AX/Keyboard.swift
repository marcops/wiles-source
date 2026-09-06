import CoreGraphics
import Foundation

/// Synthesises keystrokes with `CGEvent`, posted straight to the target pid so they never leak to
/// whatever else is frontmost. Chords (⌘F, ⇧⌘N, …) go by virtual keycode because AppKit resolves
/// menu equivalents by keycode, not character; free text goes through the unicode-string path.
enum Keyboard {
    struct Key {
        let code: CGKeyCode
    }

    struct Modifiers: OptionSet {
        let rawValue: Int
        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)

        var flags: CGEventFlags {
            var result: CGEventFlags = []
            if contains(.command) { result.insert(.maskCommand) }
            if contains(.shift) { result.insert(.maskShift) }
            if contains(.option) { result.insert(.maskAlternate) }
            if contains(.control) { result.insert(.maskControl) }
            return result
        }
    }

    private static let keyCodes: [Character: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20,
        "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30,
        "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, ";": 41,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, " ": 49, "`": 50,
    ]

    static let returnKey = Key(code: 36)
    static let tab = Key(code: 48)
    static let space = Key(code: 49)
    static let delete = Key(code: 51)
    static let escape = Key(code: 53)
    static let leftArrow = Key(code: 123)
    static let rightArrow = Key(code: 124)
    static let downArrow = Key(code: 125)
    static let upArrow = Key(code: 126)

    static func key(for character: Character) -> Key? {
        keyCodes[Character(character.lowercased())].map(Key.init)
    }

    static func press(_ key: Key, modifiers: Modifiers = [], pid: pid_t) {
        post(keyCode: key.code, modifiers: modifiers, pid: pid)
    }

    /// Presses a printable character as a chord component (e.g. "f" in ⌘F).
    static func press(character: Character, modifiers: Modifiers = [], pid: pid_t) {
        guard let key = key(for: character) else { return }
        press(key, modifiers: modifiers, pid: pid)
    }

    /// Types free text into whatever is focused in the target app.
    static func type(_ text: String, pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        for scalar in text.unicodeScalars {
            var units = [UniChar(scalar.value & 0xFFFF)]
            for isDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown) else { continue }
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &units)
                event.postToPid(pid)
            }
            Thread.sleep(forTimeInterval: 0.012)
        }
    }

    private static func post(keyCode: CGKeyCode, modifiers: Modifiers, pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        let flags = modifiers.flags
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.postToPid(pid)
        Thread.sleep(forTimeInterval: 0.03)
        up.postToPid(pid)
        Thread.sleep(forTimeInterval: 0.05)
    }
}
