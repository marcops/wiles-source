import Carbon.HIToolbox
import Foundation

/// char → (virtual keycode, needs-shift) for the machine's *current* keyboard layout, so both
/// typing and menu-shortcut chords work on ABNT2, AZERTY, etc. — not just US ANSI.
enum KeyboardLayout {
    static func entry(for character: Character) -> (code: CGKeyCode, shift: Bool)? {
        map[character]
    }

    private static let map: [Character: (code: CGKeyCode, shift: Bool)] = build()

    private static func build() -> [Character: (code: CGKeyCode, shift: Bool)] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return [:] }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data

        var result: [Character: (code: CGKeyCode, shift: Bool)] = [:]
        var deadState: UInt32 = 0

        func char(keyCode: UInt16, shift: Bool) -> Character? {
            var chars = [UniChar](repeating: 0, count: 8)
            var length = 0
            let mods: UInt32 = shift ? UInt32((shiftKey >> 8) & 0xFF) : 0
            let status = data.withUnsafeBytes { bytes -> OSStatus in
                guard let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
                return UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDown), mods,
                                      UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                      &deadState, chars.count, &length, &chars)
            }
            guard status == noErr, length > 0, let scalar = String(utf16CodeUnits: chars, count: length).unicodeScalars.first
            else { return nil }
            let c = Character(scalar)
            return c.isWhitespace && c != " " ? nil : c
        }

        for keyCode in UInt16(0) ..< 128 {
            if let c = char(keyCode: keyCode, shift: false), result[c] == nil {
                result[c] = (CGKeyCode(keyCode), false)
            }
            if let c = char(keyCode: keyCode, shift: true), result[c] == nil {
                result[c] = (CGKeyCode(keyCode), true)
            }
        }
        return result
    }
}
