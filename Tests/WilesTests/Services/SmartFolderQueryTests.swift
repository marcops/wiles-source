import XCTest
@testable import Wiles

/// Coverage for `SmartFolderService.executeQuery`/`executeContentQuery` — the `NSMetadataQuery`
/// (Spotlight) driven instance methods that `SmartFolderTests.swift` (the persistence-layer suite)
/// doesn't touch. Standalone `XCTestCase` (see `SpotlightSearchTests` precedent) needing no wiring
/// into `WilesAutomatedXCTestCase.swift`.
///
/// Only proves each call completes and calls back with a well-formed result — not that results are
/// non-empty. `SpotlightSearchTests` already established that `NSMetadataQuery`'s cold-start
/// latency is independent of whether Spotlight has the result indexed, so asserting non-empty here
/// would reintroduce the same flakiness risk. Unlike `OpenWithService`/`NetworkServerService`, this
/// path never presents system UI (a background metadata query, not a file-open/network-mount
/// request), so it's safe to exercise for real.
@MainActor
final class SmartFolderQueryTests: XCTestCase {
    func testExecuteQueryWithValidScopePathCompletes() {
        let exp = expectation(description: "executeQuery with a valid scopePath completes")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder = SmartFolder(name: "Test", searchQuery: "Desktop", scopePath: home.path)

        SmartFolderService.shared.executeQuery(for: folder) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.4)
    }

    func testExecuteQueryWithEmptyScopePathFallsBackToHomeScope() {
        // Empty scopePath takes the `NSMetadataQueryUserHomeScope` fallback branch instead of a
        // custom URL scope.
        let exp = expectation(description: "executeQuery with an empty scopePath completes")
        let folder = SmartFolder(name: "Test", searchQuery: "Desktop", scopePath: "")

        SmartFolderService.shared.executeQuery(for: folder) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.4)
    }

    func testExecuteQueryWithNonexistentScopePathFallsBackToHomeScope() {
        // A scopePath that fails FileManager.fileExists also takes the home-scope fallback branch.
        let exp = expectation(description: "executeQuery with a nonexistent scopePath completes")
        let missing = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        let folder = SmartFolder(name: "Test", searchQuery: "Desktop", scopePath: missing)

        SmartFolderService.shared.executeQuery(for: folder) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.4)
    }

    func testExecuteQueryCalledTwiceStopsThePriorQuery() {
        // Calling executeQuery again before the first completes exercises `query?.stop()` and the
        // stale-observer-removal branch (`if let existingObserver = queryObserver`). Only the second
        // call's completion should fire.
        let exp = expectation(description: "second executeQuery call completes")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folderA = SmartFolder(name: "A", searchQuery: "Desktop", scopePath: home.path)
        let folderB = SmartFolder(name: "B", searchQuery: "Documents", scopePath: home.path)

        SmartFolderService.shared.executeQuery(for: folderA) { _ in
            XCTFail("The first query's completion should not fire once superseded by a second call")
        }
        SmartFolderService.shared.executeQuery(for: folderB) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.4)
    }

    func testExecuteContentQueryCompletes() {
        let exp = expectation(description: "executeContentQuery completes")
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        SmartFolderService.shared.executeContentQuery(queryText: "test", in: dir) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.4)
    }
}
