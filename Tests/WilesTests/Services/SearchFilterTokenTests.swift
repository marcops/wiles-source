import XCTest
@testable import Wiles

/// `SearchFilterService.toggleToken` / `containsToken` — the generalized append/strip of a
/// `prefix:value` search token (L10, used by `HeaderBarView`'s quick filters). Split from
/// `FileSystemSearchAndSortTests` to keep that file under the length cap.
final class SearchFilterTokenTests: XCTestCase {
    func testToggleAppendsWhenAbsentPreservingFreeText() {
        XCTAssertEqual(SearchFilterService.toggleToken("kind:image", in: "report"), "report kind:image")
    }

    func testToggleStripsWhenPresentKeepingOtherTokens() {
        XCTAssertEqual(
            SearchFilterService.toggleToken("kind:image", in: "report kind:image date:today"),
            "report date:today")
    }

    func testContainsMatchesCaseInsensitively() {
        XCTAssertTrue(SearchFilterService.containsToken("kind:image", in: "report KIND:IMAGE"))
    }

    func testContainsReturnsFalseWhenAbsent() {
        XCTAssertFalse(SearchFilterService.containsToken("kind:image", in: "report kind:doc"))
    }

    // MARK: - extractPrefixedToken (tag-token path, used by TagsSectionView)

    func testExtractPrefixedTokenReturnsNilValueWhenAbsent() {
        let result = SearchFilterService.extractPrefixedToken(prefix: "tag:", from: "report kind:image")
        XCTAssertEqual(result.remaining, "report kind:image")
        XCTAssertNil(result.value)
    }

    func testExtractPrefixedTokenPullsValueAndKeepsOtherTokens() {
        let result = SearchFilterService.extractPrefixedToken(prefix: "tag:", from: "report tag:Work date:today")
        XCTAssertEqual(result.remaining, "report date:today")
        XCTAssertEqual(result.value, "Work")
    }

    func testExtractPrefixedTokenMatchesPrefixCaseInsensitively() {
        let result = SearchFilterService.extractPrefixedToken(prefix: "tag:", from: "TAG:Red budget")
        XCTAssertEqual(result.remaining, "budget")
        XCTAssertEqual(result.value, "Red")
    }

    func testExtractPrefixedTokenUsesFirstMatchOnly() {
        let result = SearchFilterService.extractPrefixedToken(prefix: "tag:", from: "tag:a tag:b")
        XCTAssertEqual(result.value, "a")
        XCTAssertEqual(result.remaining, "tag:b")
    }

    // MARK: - parsedQuery (analysed once per load, not per candidate file)

    func testParsedQuerySplitsTokensAndFlagsEmpty() {
        let parsed = SearchFilterService.parsedQuery(query: "  report kind:pdf  ", scope: .name, caseSensitive: false)
        XCTAssertEqual(parsed.tokens, ["report", "kind:pdf"])
        XCTAssertFalse(parsed.isEmpty)

        let blank = SearchFilterService.parsedQuery(query: "   ", scope: .name, caseSensitive: false)
        XCTAssertTrue(blank.isEmpty)
        XCTAssertTrue(blank.tokens.isEmpty)
    }

    func testParsedQueryCollectsResourceKeysPerTokenAndScope() {
        let parsed = SearchFilterService.parsedQuery(query: "date:>1d size:>1m tag:Work", scope: .name, caseSensitive: false)
        XCTAssertEqual(parsed.resourceKeys, [.contentModificationDateKey, .fileSizeKey, .tagNamesKey])

        // Content scope always needs size + mtime (the content-match cache key) even with no token.
        let contentScoped = SearchFilterService.parsedQuery(query: "hello", scope: .content, caseSensitive: false)
        XCTAssertEqual(contentScoped.resourceKeys, [.fileSizeKey, .contentModificationDateKey])
    }

    func testParsedQueryCompilesRegexForWildcardTokenOnly() {
        let parsed = SearchFilterService.parsedQuery(query: "plain no*pe kind:pdf", scope: .name, caseSensitive: false)
        XCTAssertNotNil(parsed.tokenRegexes["no*pe"])
        XCTAssertNil(parsed.tokenRegexes["plain"])
        XCTAssertNil(parsed.tokenRegexes["kind:pdf"])
    }

    func testTokensDropsEmptyAndLeadingTrailingWhitespace() {
        XCTAssertEqual(SearchFilterService.tokens(of: "  report   kind:pdf  "), ["report", "kind:pdf"])
    }

    func testTokensSplitsOnNewlinesToo() {
        XCTAssertEqual(SearchFilterService.tokens(of: "report\nkind:pdf\tdate:today"), ["report", "kind:pdf", "date:today"])
    }

    func testTokensOnEmptyOrWhitespaceOnlyQueryIsEmpty() {
        XCTAssertEqual(SearchFilterService.tokens(of: ""), [])
        XCTAssertEqual(SearchFilterService.tokens(of: "   \n\t "), [])
    }

    func testMaxContentSearchFileBytesIsTwoMegabytes() {
        XCTAssertEqual(SearchFilterService.maxContentSearchFileBytes, 2_000_000)
    }

    func testExclusiveTokenReplacesOthersInSameGroup() {
        let afterImage = SearchFilterService.toggleExclusiveToken("kind:image", groupPrefix: "kind:", in: "report")
        XCTAssertEqual(afterImage, "report kind:image")
        let afterDoc = SearchFilterService.toggleExclusiveToken("kind:doc", groupPrefix: "kind:", in: afterImage)
        XCTAssertEqual(afterDoc, "report kind:doc")
    }

    func testExclusiveTokenTogglesOffWhenReactivated() {
        XCTAssertEqual(
            SearchFilterService.toggleExclusiveToken("date:7d", groupPrefix: "date:", in: "report date:7d"),
            "report")
    }

    func testExclusiveTokenLeavesOtherGroupsAndFreeTextUntouched() {
        XCTAssertEqual(
            SearchFilterService.toggleExclusiveToken("kind:pdf", groupPrefix: "kind:", in: "report kind:image date:today"),
            "report date:today kind:pdf")
    }

    // MARK: - soleTagValue / toggledTagQuery (sidebar tag row → header tag pill)

    func testSoleTagValueReturnsTagWhenQueryIsJustThatToken() {
        XCTAssertEqual(SearchFilterService.soleTagValue(in: "tag:Red"), "Red")
        XCTAssertEqual(SearchFilterService.soleTagValue(in: "  tag:Red  "), "Red")
    }

    func testSoleTagValueIsNilWhenOtherTokensOrFreeTextPresent() {
        XCTAssertNil(SearchFilterService.soleTagValue(in: "pdf tag:Red"))
        XCTAssertNil(SearchFilterService.soleTagValue(in: "tag:Red tag:Blue"))
        XCTAssertNil(SearchFilterService.soleTagValue(in: "tag:"))
        XCTAssertNil(SearchFilterService.soleTagValue(in: ""))
        XCTAssertNil(SearchFilterService.soleTagValue(in: "report"))
    }

    func testToggledTagQueryAddsToEmptyAndToFreeText() {
        XCTAssertEqual(SearchFilterService.toggledTagQuery(tag: "Red", in: ""), "tag:Red")
        XCTAssertEqual(SearchFilterService.toggledTagQuery(tag: "Red", in: "report"), "report tag:Red")
    }

    func testToggledTagQueryRemovesTheActiveTagAndReplacesADifferentOne() {
        XCTAssertEqual(SearchFilterService.toggledTagQuery(tag: "Red", in: "report tag:red"), "report")
        XCTAssertEqual(SearchFilterService.toggledTagQuery(tag: "Blue", in: "report tag:Red"), "report tag:Blue")
    }
}
