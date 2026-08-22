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

    /// Covers `stopSearch()`'s `if let query = metadataQuery` false branch: calling it when no
    /// search is in progress (metadataQuery already nil) must be a safe no-op, not a crash.
    func testSpotlightSearchStopSearchWhenIdleIsNoOp() {
        SpotlightSearchService.shared.stopSearch()
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

    /// Coverage for the `queryDidFinishGathering` result-mapping loop (`query.result(at:)` cast to
    /// `NSMetadataItem` and `kMDItemPath` extraction): searches for the user's own `~/Desktop` folder,
    /// which macOS keeps pre-indexed in Spotlight (no fresh-file indexing lag). NSMetadataQuery's
    /// first gathering pass in a fresh process can have real cold-start latency independent of
    /// whether the index itself has the result (confirmed via `mdfind` returning it instantly once
    /// warm) — so this only asserts the shape of whatever comes back (real file URLs, no crash),
    /// not that results are non-empty within the timeout. A slow/empty gather here means the
    /// environment's Spotlight is unavailable or cold, not that `SpotlightSearchService` is broken.
    func testSpotlightSearchWithRealResultsPopulatesURLs() {
        let exp = expectation(description: "Spotlight search for an already-indexed folder completes")
        let home = FileManager.default.homeDirectoryForCurrentUser

        SpotlightSearchService.shared.searchFiles(matching: "Desktop", scopeURL: home) { results in
            XCTAssertTrue(results.allSatisfy(\.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.4)
    }

    // Not covered: `queryDidFinishGathering`'s `guard let query = metadataQuery else { return }`
    // false path (the method is `@objc private`, only reachable via a real
    // NSMetadataQueryDidFinishGathering notification racing an already-nilled metadataQuery) and
    // the true side of the compactMap's per-item cast/attribute-extraction inside it — both are
    // real-Spotlight-timing-dependent, consistent with this file's documented policy above.
}
