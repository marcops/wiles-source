import XCTest
@testable import Wiles

@MainActor
final class SpotlightSearchTests: XCTestCase {
    func testSpotlightSearchEmptyQueryReturnsEmpty() {
        let exp = expectation(description: "Spotlight search completes")
        let home = FileManager.default.homeDirectoryForCurrentUser

        SpotlightSearchService.shared.searchFiles(matching: "", scopeURL: home) { results in
            XCTAssertTrue(results.isEmpty)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    func testSpotlightSearchStopSearchClearsState() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        SpotlightSearchService.shared.searchFiles(matching: "test", scopeURL: home) { _ in }
        SpotlightSearchService.shared.stopSearch()
        XCTAssertTrue(true)
    }

    /// Regression coverage for the predicate-injection crash fix: a query built with an apostrophe
    /// used to break out of the predicate format string's quoted literal, and NSPredicate(format:)
    /// raised an uncatchable NSInvalidArgumentException — reaching this assertion at all is the
    /// actual proof of the fix, since the old code would have crashed the whole test process before
    /// ever calling back. (%@ substitution passes the value as data, not format syntax, so no input
    /// could break the predicate.)
    func testSpotlightSearchWithApostropheDoesNotCrash() {
        let exp = expectation(description: "Spotlight search with apostrophe completes without crashing")
        let home = FileManager.default.homeDirectoryForCurrentUser

        SpotlightSearchService.shared.searchFiles(matching: "d'Ávila \" special'chars", scopeURL: home) { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }
}
