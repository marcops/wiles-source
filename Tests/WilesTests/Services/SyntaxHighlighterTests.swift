@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct SyntaxHighlighterTests {
    public static func run() {
        testShortContentNotTruncated()
        testLongContentIsTruncated()
        testKeywordSplitsRunsForSupportedExtension()
        testKeywordDoesNotSplitRunsForUnsupportedExtension()
        testStringLiteralSplitsRuns()
    }

    private static func testShortContentNotTruncated() {
        let content = "let x = 1"
        let result = SyntaxHighlighterService.highlightCode(content: content, fileExtension: "swift")
        report("SyntaxHighlighter", "POS: short content is returned verbatim", result: String(result.characters) == content)
    }

    private static func testLongContentIsTruncated() {
        let content = String(repeating: "a", count: 20_000)
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
