import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct TypeAheadSelectionControllerTests {
    public static func run() {
        testSearchableCharacter()
        testNextMatchingIndex()
        testHandleCharacterKeyDownSingleLetterJumpsToMatch()
        testHandleCharacterKeyDownExtendsBufferWithinResetInterval()
        testHandleCharacterKeyDownStartsFreshBufferAfterTimeout()
        testHandleCharacterKeyDownCyclesThroughRepeatedLetter()
        testHandleCharacterKeyDownRejectsNonPrintableInput()
    }

    private static func makeItems(_ names: [String]) -> [FileItem] {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        return names.map { FileItem.load(url: dir.appendingPathComponent($0), icon: NSImage()) }
    }

    private static func testSearchableCharacter() {
        report(
            "Keyboard/TypeAhead", "POS: a plain letter is a searchable character",
            result: TypeAheadSelectionController.searchableCharacter(from: "b") == "b")
        report(
            "Keyboard/TypeAhead", "NEG: Space is excluded (reserved for Quick Look)",
            result: TypeAheadSelectionController.searchableCharacter(from: " ") == nil)
        report(
            "Keyboard/TypeAhead", "NEG: Return/newline is excluded",
            result: TypeAheadSelectionController.searchableCharacter(from: "\r") == nil)
        report(
            "Keyboard/TypeAhead", "NEG: a private-use function-key scalar (F2) is excluded",
            result: TypeAheadSelectionController.searchableCharacter(from: "\u{F705}") == nil)
        report(
            "Keyboard/TypeAhead", "NEG: multi-character input (IME composition) is excluded",
            result: TypeAheadSelectionController.searchableCharacter(from: "ab") == nil)
        report(
            "Keyboard/TypeAhead", "NEG: nil characters is excluded",
            result: TypeAheadSelectionController.searchableCharacter(from: nil) == nil)
    }

    private static func testNextMatchingIndex() {
        let items = makeItems(["apple", "Banana", "cherry", "banjo"])
        report(
            "Keyboard/TypeAhead", "POS: finds the next item after the current index matching the prefix, case-insensitively",
            result: TypeAheadSelectionController.nextMatchingIndex(in: items, startingAfter: 0, prefix: "b") == 1)
        report(
            "Keyboard/TypeAhead", "POS: wraps around to the top when no match remains after the current index",
            result: TypeAheadSelectionController.nextMatchingIndex(in: items, startingAfter: 1, prefix: "a") == 0)
        report(
            "Keyboard/TypeAhead", "POS: cycles past the currently-matching item to the NEXT one sharing the prefix",
            result: TypeAheadSelectionController.nextMatchingIndex(in: items, startingAfter: 1, prefix: "b") == 3)
        report(
            "Keyboard/TypeAhead", "NEG: no item matches the prefix",
            result: TypeAheadSelectionController.nextMatchingIndex(in: items, startingAfter: 0, prefix: "zzz") == nil)
        report(
            "Keyboard/TypeAhead", "NEG: empty items list",
            result: TypeAheadSelectionController.nextMatchingIndex(in: [], startingAfter: 0, prefix: "a") == nil)
    }

    private static func testHandleCharacterKeyDownSingleLetterJumpsToMatch() {
        let items = makeItems(["apple", "banana", "cherry"])
        let appState = AppState()
        appState.fileSystem.items = items
        appState.selection.selectedURLs = [items[0].url]
        appState.selection.keyboardSelectionAnchorURL = items[0].url

        var controller = TypeAheadSelectionController()
        let handled = controller.handleCharacterKeyDown(characters: "c", appState: appState)
        report(
            "Keyboard/TypeAhead", "POS: typing 'c' is handled and selects the item starting with 'c'",
            result: handled && appState.selection.selectedURLs == [items[2].url])
    }

    private static func testHandleCharacterKeyDownExtendsBufferWithinResetInterval() {
        let items = makeItems(["apple", "bob", "bobby"])
        let appState = AppState()
        appState.fileSystem.items = items
        appState.selection.selectedURLs = [items[0].url]
        appState.selection.keyboardSelectionAnchorURL = items[0].url

        var controller = TypeAheadSelectionController()
        let start = Date()
        _ = controller.handleCharacterKeyDown(characters: "b", now: start, appState: appState)
        // "b" alone matches "bob" (index 1) first, right after the anchor at index 0.
        let afterFirstLetter = appState.selection.selectedURLs == [items[1].url]

        _ = controller.handleCharacterKeyDown(characters: "o", now: start.addingTimeInterval(0.2), appState: appState)
        _ = controller.handleCharacterKeyDown(characters: "b", now: start.addingTimeInterval(0.4), appState: appState)
        _ = controller.handleCharacterKeyDown(characters: "b", now: start.addingTimeInterval(0.6), appState: appState)
        _ = controller.handleCharacterKeyDown(characters: "y", now: start.addingTimeInterval(0.8), appState: appState)
        report(
            "Keyboard/TypeAhead",
            "POS: quick successive keystrokes extend the buffer to match the longer, more specific name",
            result: afterFirstLetter && appState.selection.selectedURLs == [items[2].url])
    }

    private static func testHandleCharacterKeyDownStartsFreshBufferAfterTimeout() {
        let items = makeItems(["cat", "bob"])
        let appState = AppState()
        appState.fileSystem.items = items
        appState.selection.selectedURLs = [items[0].url]
        appState.selection.keyboardSelectionAnchorURL = items[0].url

        var controller = TypeAheadSelectionController()
        let start = Date()
        _ = controller.handleCharacterKeyDown(characters: "b", now: start, appState: appState)
        // A long pause before "c" must start a fresh "c" buffer, not extend to "bc" (which matches
        // nothing and would leave the selection stuck on "bob" instead of jumping to "cat").
        _ = controller.handleCharacterKeyDown(characters: "c", now: start.addingTimeInterval(5), appState: appState)
        report(
            "Keyboard/TypeAhead",
            "POS: a pause beyond the reset interval starts a fresh one-character buffer instead of extending it",
            result: appState.selection.selectedURLs == [items[0].url])
    }

    private static func testHandleCharacterKeyDownCyclesThroughRepeatedLetter() {
        let items = makeItems(["bob", "bella", "beth"])
        let appState = AppState()
        appState.fileSystem.items = items
        appState.selection.selectedURLs = [items[0].url]
        appState.selection.keyboardSelectionAnchorURL = items[0].url

        var controller = TypeAheadSelectionController()
        let start = Date()
        _ = controller.handleCharacterKeyDown(characters: "b", now: start, appState: appState)
        let firstMatch = appState.selection.selectedURLs

        _ = controller.handleCharacterKeyDown(characters: "b", now: start.addingTimeInterval(5), appState: appState)
        let secondMatch = appState.selection.selectedURLs

        report(
            "Keyboard/TypeAhead",
            "POS: repeating the same letter after the buffer resets cycles to the next item sharing that letter",
            result: firstMatch == [items[1].url] && secondMatch == [items[2].url] && firstMatch != secondMatch)
    }

    private static func testHandleCharacterKeyDownRejectsNonPrintableInput() {
        let appState = AppState()
        var controller = TypeAheadSelectionController()
        let handled = controller.handleCharacterKeyDown(characters: " ", appState: appState)
        report(
            "Keyboard/TypeAhead", "NEG: Space is not accepted into the type-ahead buffer",
            result: !handled)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
