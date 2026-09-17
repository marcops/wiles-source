import AppKit
@testable import Wiles

/// Regression test for a real reported bug: pressing Return to commit an in-place rename did
/// nothing. The fix moved commit detection into `InlineRenameField.isCommitCharacter(_:)` — a
/// plain, pure function extracted from the `.onKeyPress` handler (which itself can't be driven
/// from a unit test since `KeyPress` has no public initializer). Also covers the numeric-keypad
/// Enter key, which reports the legacy ETX character (`"\u{3}"`) instead of `"\r"` and was still
/// silently ignored by an earlier version of this fix that only matched `.return`.
@MainActor
public struct InlineRenameFieldTests {
    public static func run() {
        testMainReturnKeyCommits()
        testKeypadEnterKeyCommits()
        testOtherCharactersDoNotCommit()
        testComputeHeightSingleLineForShortText()
        testComputeHeightGrowsExactlyOneLinePerWrap()
        testComputeHeightNeverGoesBelowOneLine()
    }

    private static func testMainReturnKeyCommits() {
        report(
            "View/InlineRenameField",
            "POS: the main Return key (\\r) is recognized as a commit character",
            result: InlineRenameField.isCommitCharacter("\r"))
    }

    private static func testKeypadEnterKeyCommits() {
        report(
            "View/InlineRenameField",
            "POS: the keypad Enter key (ETX, \\u{3}) is recognized as a commit character",
            result: InlineRenameField.isCommitCharacter("\u{3}"))
    }

    private static func testOtherCharactersDoNotCommit() {
        report("View/InlineRenameField", "NEG: a regular letter does not commit", result: !InlineRenameField.isCommitCharacter("a"))
        report("View/InlineRenameField", "NEG: a line feed (\\n) does not commit", result: !InlineRenameField.isCommitCharacter("\n"))
        report("View/InlineRenameField", "NEG: the space character does not commit", result: !InlineRenameField.isCommitCharacter(" "))
        report("View/InlineRenameField", "NEG: the tab character does not commit", result: !InlineRenameField.isCommitCharacter("\t"))
    }

    /// Regression: `TextField(axis: .vertical)` used to reserve one line more than actually needed.
    private static func testComputeHeightSingleLineForShortText() {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let height = InlineRenameField.computeHeight(text: "abc", nsFont: font, availableWidth: 400)
        let singleLineHeight = font.ascender - font.descender + font.leading
        let expected = singleLineHeight + LayoutTokens.gridCardLabelVerticalPadding
        report(
            "View/InlineRenameField",
            "POS: computeHeight reports one line's height for text that fits on one line, not two",
            result: abs(height - expected) < 0.01)
    }

    private static func testComputeHeightGrowsExactlyOneLinePerWrap() {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let longText = String(repeating: "wrap", count: 40)
        let wrappedLineCount = FinderStyleTruncationService.wrappedLines(longText, font: font, maxWidth: 120).count
        let height = InlineRenameField.computeHeight(text: longText, nsFont: font, availableWidth: 120)
        let singleLineHeight = font.ascender - font.descender + font.leading
        let expected = singleLineHeight * CGFloat(wrappedLineCount) + LayoutTokens.gridCardLabelVerticalPadding
        report(
            "View/InlineRenameField",
            "POS: computeHeight scales exactly with the actual wrapped line count (\(wrappedLineCount) lines), never one ahead of it",
            result: wrappedLineCount > 1 && abs(height - expected) < 0.01)
    }

    private static func testComputeHeightNeverGoesBelowOneLine() {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let height = InlineRenameField.computeHeight(text: "", nsFont: font, availableWidth: 400)
        let singleLineHeight = font.ascender - font.descender + font.leading
        let expected = singleLineHeight + LayoutTokens.gridCardLabelVerticalPadding
        report(
            "View/InlineRenameField",
            "POS: computeHeight floors at one line's height for empty text",
            result: abs(height - expected) < 0.01)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
