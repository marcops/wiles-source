import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct SyntaxHighlighterTests {
    public static func run() {
        testShortContentNotTruncated()
        testLongContentIsTruncated()
        testKeywordSplitsRunsForSupportedExtension()
        testKeywordDoesNotSplitRunsForUnsupportedExtension()
        testStringLiteralSplitsRuns()
        testEmptyContentReturnsEmpty()
        testCommentSplitsRuns()
        testUppercaseExtensionIsTreatedAsSupported()
        testPythonExtensionIsHighlighted()
        testYmlExtensionWithNoMatchingTokensStaysSingleRun()
    }

    private static func testEmptyContentReturnsEmpty() {
        let result = SyntaxHighlighterService.highlightCode(content: "", fileExtension: "swift")
        report("SyntaxHighlighter", "EDGE: empty content returns empty attributed string", result: String(result.characters).isEmpty)
    }

    private static func testCommentSplitsRuns() {
        let content = "// a comment\nlet x = 1"
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift")
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: line comment highlighting splits the string into multiple color runs", result: runCount > 1)
    }

    private static func testUppercaseExtensionIsTreatedAsSupported() {
        let content = "func doSomething() {}"
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "SWIFT")
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: uppercase file extension is lowercased and still highlighted", result: runCount > 1)
    }

    private static func testPythonExtensionIsHighlighted() {
        let content = "def foo():\n    return True"
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "py")
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: .py extension highlights keywords across multiple runs", result: runCount > 1)
    }

    private static func testYmlExtensionWithNoMatchingTokensStaysSingleRun() {
        let content = "no keywords or strings here"
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "yml")
        let runCount = result.runs.count
        report("SyntaxHighlighter", "EDGE: supported extension with no matching tokens keeps a single uniform run", result: runCount == 1)
    }

    private static func testShortContentNotTruncated() {
        let content = "let x = 1"
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift")
        report("SyntaxHighlighter", "POS: short content is returned verbatim", result: String(result.characters) == content)
    }

    private static func testLongContentIsTruncated() {
        let content = String(repeating: "a", count: 20000)
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift")
        let text = String(result.characters)
        report("SyntaxHighlighter", "NEG: content over 10k chars is truncated", result: text.count < content.count && text.contains("(truncated)"))
    }

    private static func testKeywordSplitsRunsForSupportedExtension() {
        let content = "func doSomething() {}"
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift")
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: keyword highlighting splits the string into multiple color runs for .swift", result: runCount > 1)
    }

    private static func testKeywordDoesNotSplitRunsForUnsupportedExtension() {
        let content = "func doSomething() {}"
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "txt")
        let runCount = result.runs.count
        report("SyntaxHighlighter", "NEG: unsupported extension keeps a single uniform run (no per-token color)", result: runCount == 1)
    }

    private static func testStringLiteralSplitsRuns() {
        let content = "let s = \"hello world\""
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift")
        let runCount = result.runs.count
        report("SyntaxHighlighter", "POS: string literal highlighting splits the string into multiple color runs", result: runCount > 1)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
