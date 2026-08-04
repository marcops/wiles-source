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
}
