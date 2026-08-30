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
}
