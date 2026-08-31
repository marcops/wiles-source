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
    /// Spotlight's cold-start / unindexed-scope latency is unbounded in a headless runner, so every
    /// test caps the gather at 1 s (production stays 20 s) and waits comfortably past that — the
    /// completion always fires, with real results or an empty timeout result.
    private static let testQueryTimeout: Duration = .seconds(1)
    private static let waitTimeout: TimeInterval = 4

    private func makeService() -> SmartFolderService {
        let service = SmartFolderService()
        service.queryTimeout = Self.testQueryTimeout
        return service
    }

    func testExecuteQueryWithValidScopePathCompletes() {
        let exp = expectation(description: "executeQuery with a valid scopePath completes")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder = SmartFolder(name: "Test", searchQuery: "Desktop", scopePath: home.path)

        let service = makeService()
        service.executeQuery(for: folder) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: Self.waitTimeout)
    }

    func testExecuteQueryWithEmptyScopePathFallsBackToHomeScope() {
        // Empty scopePath takes the `NSMetadataQueryUserHomeScope` fallback branch instead of a
        // custom URL scope.
        let exp = expectation(description: "executeQuery with an empty scopePath completes")
        let folder = SmartFolder(name: "Test", searchQuery: "Desktop", scopePath: "")

        let service = makeService()
        service.executeQuery(for: folder) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: Self.waitTimeout)
    }

    func testExecuteQueryWithNonexistentScopePathFallsBackToHomeScope() {
        // A scopePath that fails FileManager.fileExists also takes the home-scope fallback branch.
        let exp = expectation(description: "executeQuery with a nonexistent scopePath completes")
        let missing = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        let folder = SmartFolder(name: "Test", searchQuery: "Desktop", scopePath: missing)

        let service = makeService()
        service.executeQuery(for: folder) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: Self.waitTimeout)
    }

    func testExecuteQueryCalledTwiceStopsThePriorQuery() {
        // Calling executeQuery again before the first completes exercises `query?.stop()` and the
        // stale-observer-removal branch (`if let existingObserver = queryObserver`). Only the second
        // call's completion should fire.
        let exp = expectation(description: "second executeQuery call completes")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folderA = SmartFolder(name: "A", searchQuery: "Desktop", scopePath: home.path)
        let folderB = SmartFolder(name: "B", searchQuery: "Documents", scopePath: home.path)

        // Two calls on the SAME instance: the second supersedes the first (staleness token).
        let service = makeService()
        service.executeQuery(for: folderA) { _ in
            XCTFail("The first query's completion should not fire once superseded by a second call")
        }
        service.executeQuery(for: folderB) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: Self.waitTimeout)
    }

    /// BA-108: `SmartFolderService` is now per-`AppState`, not `.shared`. Two independent instances
    /// (as two open windows would have) must NOT share the staleness token — window A's smart-folder
    /// run must still deliver its own results when window B starts its own run in parallel. Under
    /// the old `.shared` instance, instance B's fresh token discarded instance A's completion.
    func testTwoInstancesDoNotShareStalenessState() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folderA = SmartFolder(name: "A", searchQuery: "Desktop", scopePath: home.path)
        let folderB = SmartFolder(name: "B", searchQuery: "Documents", scopePath: home.path)
        let windowA = makeService()
        let windowB = makeService()
        let expA = expectation(description: "window A's run still delivers its own results")
        let expB = expectation(description: "window B's run delivers its results")

        windowA.executeQuery(for: folderA) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            expA.fulfill()
        }
        windowB.executeQuery(for: folderB) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            expB.fulfill()
        }

        wait(for: [expA, expB], timeout: Self.waitTimeout)
    }

    func testExecuteContentQueryCompletes() {
        let exp = expectation(description: "executeContentQuery completes")
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = makeService()
        service.executeContentQuery(queryText: "test", in: dir) { items in
            XCTAssertTrue(items.allSatisfy(\.url.isFileURL))
            exp.fulfill()
        }

        wait(for: [exp], timeout: Self.waitTimeout)
    }
}
