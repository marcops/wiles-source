import Foundation

/// Finder-style find-as-you-type: typing printable characters while the file list has focus
/// jumps the selection to the next item (in display order, wrapping) whose name starts with the
/// buffered text. Extracted from `GlobalKeyMonitor.KeyMonitorNSView` (mirrors `KeyboardZoomController`)
/// so the buffer/timeout state is unit-testable without an `NSView`/window.
@MainActor
struct TypeAheadSelectionController {
    /// Keystrokes arriving within this interval of the previous one extend the search buffer;
    /// a longer pause starts a fresh one-character buffer instead — same threshold Finder uses.
    private static let resetInterval: TimeInterval = 1.0

    private var buffer = ""
    private var lastKeystrokeDate: Date?

    /// Handles a single-character keydown with no Command/Control/Option modifier held. Returns
    /// `true` if `characters` was a plain printable character accepted into the search buffer
    /// (caller should swallow the event); `false` for anything else (Space, Return, arrows/
    /// function keys, which report non-letter scalars here, multi-scalar IME input, ...).
    mutating func handleCharacterKeyDown(characters: String?, now: Date = Date(), appState: AppState) -> Bool {
        guard let character = Self.searchableCharacter(from: characters) else { return false }

        if let lastKeystrokeDate, now.timeIntervalSince(lastKeystrokeDate) <= Self.resetInterval {
            buffer.append(character)
        } else {
            buffer = String(character)
        }
        lastKeystrokeDate = now

        selectNextMatch(appState: appState)
        return true
    }

    /// A single printable, non-whitespace `Character` extracted from `charactersIgnoringModifiers`
    /// (which already applies Shift for casing), or `nil` when the key wasn't a plain typeable
    /// character — Space is excluded so it keeps triggering Quick Look, not a search reset.
    static func searchableCharacter(from characters: String?) -> Character? {
        guard let characters, characters.count == 1, let character = characters.first else { return nil }
        guard isTypeAheadCandidate(character) else { return nil }
        return character
    }

    /// A character that could plausibly start/continue a filename search — letters, digits, and
    /// ordinary symbol/punctuation marks. Excludes control characters (Return, Delete, arrows/
    /// F-keys reporting private-use scalars here) and whitespace (Space stays Quick Look's).
    private static func isTypeAheadCandidate(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character.isSymbol || character.isPunctuation
    }

    /// Moves selection to the next item (current position onward, wrapping to the top) whose
    /// name starts with `buffer`, case-insensitively — same "single selection + anchor" update
    /// shape as `KeyboardSelectionNavigator.moveSelection`. Starting just after the current item
    /// (rather than always from the top) is what lets repeating the same letter after the buffer
    /// resets cycle through every item sharing that first letter instead of reselecting the same one.
    private func selectNextMatch(appState: AppState) {
        let items = appState.fileSystem.items
        guard !buffer.isEmpty else { return }
        let indexByURL = appState.fileSystem.indexByURL
        let currentURL = appState.selection.keyboardSelectionAnchorURL ?? appState.selection.selectedURLs.first
        let currentIndex = currentURL.flatMap { indexByURL[$0] } ?? -1

        guard let matchIndex = Self.nextMatchingIndex(in: items, startingAfter: currentIndex, prefix: buffer) else { return }

        let matchedURL = items[matchIndex].url
        appState.selection.keyboardSelectionAnchorURL = matchedURL
        appState.selection.selectedURLs = [matchedURL]
        appState.selection.lastMovedURL = matchedURL
    }

    /// Search order starting just after `startingAfter`, wrapping to the top. Returns `nil` when
    /// `items` is empty or nothing matches `prefix`.
    static func nextMatchingIndex(in items: [FileItem], startingAfter: Int, prefix: String) -> Int? {
        guard !items.isEmpty else { return nil }
        let lowercasedPrefix = prefix.lowercased()
        for offset in 1 ... items.count {
            let index = (startingAfter + offset) % items.count
            if items[index].name.lowercased().hasPrefix(lowercasedPrefix) {
                return index
            }
        }
        return nil
    }
}
