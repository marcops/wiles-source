import CoreGraphics
import Foundation

/// Synthesises keystrokes with `CGEvent` and delivers them with `postToPid` — straight to the
/// Wiles process, regardless of what window has focus. This means the machine can be used
/// normally while the suite runs (session-tap posting would interleave with the operator's own
/// typing). Chords (⌘F, ⇧⌘N, …) go by virtual keycode with explicit modifier flagsChanged
/// transitions because AppKit resolves menu equivalents by keycode + real modifier state.
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
        if let entry = KeyboardLayout.entry(for: character) { return Key(code: entry.code) }
        return keyCodes[Character(character.lowercased())].map(Key.init)
    }

    static func press(_ key: Key, modifiers: Modifiers = [], pid: pid_t) {
        post(keyCode: key.code, modifiers: modifiers, pid: pid)
    }

    /// Presses a printable character as a chord component (e.g. "f" in ⌘F).
    static func press(character: Character, modifiers: Modifiers = [], pid: pid_t) {
        guard let key = key(for: character) else { return }
        press(key, modifiers: modifiers, pid: pid)
    }

    static func type(_ text: String, pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        for character in text {
            if let (code, needsShift) = keyStroke(for: character) {
                emit(source: source, keyCode: code, keyDown: true, flags: needsShift ? .maskShift : [], pid: pid)
                emit(source: source, keyCode: code, keyDown: false, flags: needsShift ? .maskShift : [], pid: pid)
            } else {
                typeUnicode(character, source: source, pid: pid)
            }
            Timing.pause(Timing.keyStroke)
        }
        Timing.pause(Timing.brief)
    }

    private static func keyStroke(for character: Character) -> (CGKeyCode, Bool)? {
        if let entry = KeyboardLayout.entry(for: character) { return (entry.code, entry.shift) }
        if let code = keyCodes[character] { return (code, false) }
        if let lower = character.lowercased().first, let code = keyCodes[lower], character.isUppercase {
            return (code, true)
        }
        return shiftedSymbols[character].map { ($0, true) }
    }

    private static let shiftedSymbols: [Character: CGKeyCode] = [
        "_": 27, ":": 41, "?": 44, "(": 25, ")": 29, "*": 28, "&": 26, "^": 22, "%": 23,
        "$": 21, "#": 20, "@": 19, "!": 18, "+": 24, "~": 50, "|": 42, "{": 33, "}": 30,
    ]

    private static func typeUnicode(_ character: Character, source: CGEventSource?, pid: pid_t) {
        var units = Array(String(character).utf16)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown) else { continue }
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            event.postToPid(pid)
        }
    }

    private static func post(keyCode: CGKeyCode, modifiers: Modifiers, pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        let modifierKeys = modifiers.keyCodes
        var accumulated: CGEventFlags = []

        for (code, flag) in modifierKeys {
            accumulated.insert(flag)
            emit(source: source, keyCode: code, keyDown: true, flags: accumulated, pid: pid)
        }
        emit(source: source, keyCode: keyCode, keyDown: true, flags: accumulated, pid: pid)
        Timing.pause(Timing.brief)
        emit(source: source, keyCode: keyCode, keyDown: false, flags: accumulated, pid: pid)
        for (code, flag) in modifierKeys.reversed() {
            accumulated.remove(flag)
            emit(source: source, keyCode: code, keyDown: false, flags: accumulated, pid: pid)
        }
        Timing.pause(Timing.brief)
    }

    private static func emit(source: CGEventSource?, keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags, pid: pid_t) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else { return }
        event.flags = flags
        event.postToPid(pid)
        Timing.pause(Timing.keyStroke)
    }
}

extension Keyboard.Modifiers {
    /// Virtual keycodes + matching event flag for each held modifier, in a stable press order.
    var keyCodes: [(CGKeyCode, CGEventFlags)] {
        var result: [(CGKeyCode, CGEventFlags)] = []
        if contains(.command) { result.append((55, .maskCommand)) }
        if contains(.shift) { result.append((56, .maskShift)) }
        if contains(.option) { result.append((58, .maskAlternate)) }
        if contains(.control) { result.append((59, .maskControl)) }
        return result
    }
}
