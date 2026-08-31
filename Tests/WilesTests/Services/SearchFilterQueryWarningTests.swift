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

    // MARK: - invalid size:/date: filter tokens (finding ML-140)

    func testSizeFilterWithUnknownUnitWarns() {
        XCTAssertEqual(
            SearchFilterService.queryWarning(for: "size:>10zz", scope: .name),
            .invalidFilterToken(token: "size:>10zz"))
    }

    func testSizeFilterWithNoDigitsWarns() {
        XCTAssertEqual(
            SearchFilterService.queryWarning(for: "size:>", scope: .name),
            .invalidFilterToken(token: "size:>"))
    }

    func testValidSizeFiltersHaveNoWarning() {
        XCTAssertNil(SearchFilterService.queryWarning(for: "size:>10", scope: .name))
        XCTAssertNil(SearchFilterService.queryWarning(for: "size:<=2gb", scope: .name))
        XCTAssertNil(SearchFilterService.queryWarning(for: "size:512kb", scope: .name))
    }

    func testDateFilterWithNoNumberWarns() {
        XCTAssertEqual(
            SearchFilterService.queryWarning(for: "date:>abc", scope: .name),
            .invalidFilterToken(token: "date:>abc"))
    }

    func testValidDateFiltersHaveNoWarning() {
        XCTAssertNil(SearchFilterService.queryWarning(for: "date:>7d", scope: .name))
        XCTAssertNil(SearchFilterService.queryWarning(for: "date:today", scope: .name))
        // Unknown date unit is treated as days by design — not "invalid".
        XCTAssertNil(SearchFilterService.queryWarning(for: "date:>10zz", scope: .name))
    }

    func testKindExtTagTokensAreNeverInvalid() {
        // These fall back to a substring match, so any value is a legitimate (if odd) filter.
        XCTAssertNil(SearchFilterService.queryWarning(for: "kind:whatever", scope: .name))
        XCTAssertNil(SearchFilterService.queryWarning(for: "ext:qqq", scope: .name))
        XCTAssertNil(SearchFilterService.queryWarning(for: "tag:Anything", scope: .name))
    }

    func testInvalidFilterTokenReportedEvenAlongsideValidText() {
        XCTAssertEqual(
            SearchFilterService.queryWarning(for: "report size:>10zz", scope: .name),
            .invalidFilterToken(token: "size:>10zz"))
    }
}
