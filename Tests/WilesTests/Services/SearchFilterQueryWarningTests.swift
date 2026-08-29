import XCTest
@testable import Wiles

/// `SearchFilterService.queryWarning` — explains a legitimately-empty search result (L30): a
/// too-short content query or an uncompilable regex, so the empty-results view can say why
/// instead of just "No Results Found".
final class SearchFilterQueryWarningTests: XCTestCase {
    func testEmptyQueryHasNoWarning() {
        XCTAssertNil(SearchFilterService.queryWarning(for: "   ", scope: .both))
    }

    func testShortPlainTextIsNoOpForNameScope() {
        XCTAssertNil(SearchFilterService.queryWarning(for: "ab", scope: .name))
    }

    func testShortPlainTextWarnsForContentScope() {
        XCTAssertEqual(
            SearchFilterService.queryWarning(for: "ab", scope: .content),
            .contentQueryTooShort(minimum: SearchFilterService.minContentQueryLength))
    }

    func testShortPlainTextWarnsForBothScope() {
        XCTAssertEqual(
            SearchFilterService.queryWarning(for: "ab", scope: .both),
            .contentQueryTooShort(minimum: 3))
    }

    func testAtThresholdLengthHasNoWarning() {
        XCTAssertNil(SearchFilterService.queryWarning(for: "abc", scope: .both))
    }

    func testFilterTokensDoNotCountTowardContentLength() {
        // `kind:pdf` is a filter token, not content text — a bare `kind:pdf` query is not "too short".
        XCTAssertNil(SearchFilterService.queryWarning(for: "kind:pdf", scope: .both))
    }

    func testInvalidRegexTokenWarns() {
        XCTAssertEqual(SearchFilterService.queryWarning(for: "r:[", scope: .name), .invalidRegex)
    }

    func testValidRegexTokenHasNoWarning() {
        XCTAssertNil(SearchFilterService.queryWarning(for: "r:^foo.*bar$", scope: .name))
    }

    func testInvalidRegexTakesPrecedenceOverTooShort() {
        XCTAssertEqual(SearchFilterService.queryWarning(for: "r:(", scope: .both), .invalidRegex)
    }
}
