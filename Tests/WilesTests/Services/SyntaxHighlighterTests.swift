import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct SyntaxHighlighterTests {
    public static func run() async {
        await testShortContentNotTruncated()

        await testLongContentIsTruncated()

        await testKeywordSplitsRunsForSupportedExtension()

        await testKeywordDoesNotSplitRunsForUnsupportedExtension()

        await testStringLiteralSplitsRuns()

        await testEmptyContentReturnsEmpty()

        await testCommentSplitsRuns()

        await testUppercaseExtensionIsTreatedAsSupported()

        await testPythonExtensionIsHighlighted()

        await testYmlExtensionWithNoMatchingTokensStaysSingleRun()

        await testUrlInsideStringLiteralIsNotColouredAsComment()

        await testRealTrailingCommentAfterStringIsStillColoured()
    }

    /// Regression: the strings pass runs after the `//` comment pass, so a `//` that is actually
    /// inside a string literal (a URL) stays string-coloured instead of bleeding comment-green.
    private static func testUrlInsideStringLiteralIsNotColouredAsComment() async {
        let content = "let s = \"https://example.com\""
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift", language: .english)
        let hasCommentColour = result.runs.contains { $0.appKit.foregroundColor == NSColor.systemGreen }
        report("SyntaxHighlighter", "REG: `//` inside a string literal is not re-coloured as a comment", result: !hasCommentColour)
    }

    private static func testRealTrailingCommentAfterStringIsStillColoured() async {
        let content = "let s = \"hi\" // note"
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift", language: .english)
        let hasCommentColour = result.runs.contains { $0.appKit.foregroundColor == NSColor.systemGreen }
        let hasStringColour = result.runs.contains { $0.appKit.foregroundColor == NSColor.systemOrange }
        report(
            "SyntaxHighlighter",
            "POS: a real trailing comment after a string keeps both string and comment colours",
            result: hasCommentColour && hasStringColour)
    }

    private static func testEmptyContentReturnsEmpty() async {
        let result = await SyntaxHighlighterService.highlightCode(content: "", fileExtension: "swift", language: .english)
        report("SyntaxHighlighter", "EDGE: empty content returns empty attributed string", result: String(result.characters).isEmpty)
    }

    private static func testCommentSplitsRuns() async {
        let content = "// a comment\nlet x = 1"
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift", language: .english)
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: line comment highlighting splits the string into multiple color runs", result: runCount > 1)
    }

    private static func testUppercaseExtensionIsTreatedAsSupported() async {
        let content = "func doSomething() {}"
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "SWIFT", language: .english)
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: uppercase file extension is lowercased and still highlighted", result: runCount > 1)
    }

    private static func testPythonExtensionIsHighlighted() async {
        let content = "def foo():\n    return True"
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "py", language: .english)
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: .py extension highlights keywords across multiple runs", result: runCount > 1)
    }

    private static func testYmlExtensionWithNoMatchingTokensStaysSingleRun() async {
        let content = "no keywords or strings here"
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "yml", language: .english)
        let runCount = result.runs.count
        report("SyntaxHighlighter", "EDGE: supported extension with no matching tokens keeps a single uniform run", result: runCount == 1)
    }

    private static func testShortContentNotTruncated() async {
        let content = "let x = 1"
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift", language: .english)
        report("SyntaxHighlighter", "POS: short content is returned verbatim", result: String(result.characters) == content)
    }

    private static func testLongContentIsTruncated() async {
        let content = String(repeating: "a", count: 20000)
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift", language: .english)
        let text = String(result.characters)
        report("SyntaxHighlighter", "NEG: content over 10k chars is truncated", result: text.count < content.count && text.contains("(truncated)"))
    }

    private static func testKeywordSplitsRunsForSupportedExtension() async {
        let content = "func doSomething() {}"
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift", language: .english)
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: keyword highlighting splits the string into multiple color runs for .swift", result: runCount > 1)
    }

    private static func testKeywordDoesNotSplitRunsForUnsupportedExtension() async {
        let content = "func doSomething() {}"
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "txt", language: .english)
        let runCount = result.runs.count
        report("SyntaxHighlighter", "NEG: unsupported extension keeps a single uniform run (no per-token color)", result: runCount == 1)
    }

    private static func testStringLiteralSplitsRuns() async {
        let content = "let s = \"hello world\""
        let result = await SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift", language: .english)
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: string literal highlighting splits the string into multiple color runs", result: runCount > 1)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
