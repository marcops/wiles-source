import XCTest
@testable import Wiles

/// Standalone dedicated suite for `FinderStyleTruncationService` — follows the standalone-XCTestCase
/// precedent (see `TemplateRenderingServiceTests`) since this is a new source file with no prior
/// coverage and needs no wiring elsewhere.
final class FinderStyleTruncationServiceTests: XCTestCase {
    private let font = NSFont.systemFont(ofSize: 12)

    func testShortNameThatFitsIsReturnedUnchanged() {
        let result = FinderStyleTruncationService.truncatedMiddle("short.txt", font: font, maxWidth: 400, maxLines: 2)
        XCTAssertEqual(result, "short.txt")
    }

    func testVeryLongNameIsTruncatedWithMiddleEllipsis() {
        let longName = String(repeating: "a", count: 200) + ".txt"
        let result = FinderStyleTruncationService.truncatedMiddle(longName, font: font, maxWidth: 120, maxLines: 2)

        XCTAssertNotEqual(result, longName)
        XCTAssertTrue(result.contains("…"))
        // Middle-truncation keeps the start AND the end visible (unlike tail truncation, which
        // would drop the ".txt" extension entirely) — this is the whole point of the feature.
        XCTAssertTrue(result.hasPrefix("a"))
        XCTAssertTrue(result.hasSuffix(".txt"))
    }

    /// The result is pre-split into real lines joined by "\n" — count those directly.
    func testTruncatedResultActuallyFitsWithinMaxLines() {
        let longName = String(repeating: "b", count: 300)
        let result = FinderStyleTruncationService.truncatedMiddle(longName, font: font, maxWidth: 100, maxLines: 2)
        XCTAssertLessThanOrEqual(result.split(separator: "\n", omittingEmptySubsequences: false).count, 2)
    }

    func testEmptyNameReturnsEmpty() {
        XCTAssertEqual(FinderStyleTruncationService.truncatedMiddle("", font: font, maxWidth: 200, maxLines: 2), "")
    }

    func testZeroMaxWidthReturnsNameUnchanged() {
        let name = "some_file.txt"
        XCTAssertEqual(FinderStyleTruncationService.truncatedMiddle(name, font: font, maxWidth: 0, maxLines: 2), name)
    }

    func testZeroMaxLinesReturnsNameUnchanged() {
        let name = "some_file.txt"
        XCTAssertEqual(FinderStyleTruncationService.truncatedMiddle(name, font: font, maxWidth: 200, maxLines: 0), name)
    }

    func testMoreAvailableLinesTruncatesLessAggressively() {
        let longName = String(repeating: "c", count: 200) + ".txt"
        let oneLine = FinderStyleTruncationService.truncatedMiddle(longName, font: font, maxWidth: 120, maxLines: 1)
        let twoLines = FinderStyleTruncationService.truncatedMiddle(longName, font: font, maxWidth: 120, maxLines: 2)

        // More available lines means more room, so the 2-line result should keep at least as many
        // characters visible as the 1-line result for the same name/width.
        XCTAssertGreaterThanOrEqual(twoLines.count, oneLine.count)
    }
}
