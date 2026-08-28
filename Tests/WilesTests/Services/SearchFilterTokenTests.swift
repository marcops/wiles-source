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
}
