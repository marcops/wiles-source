import XCTest
@testable import Wiles

/// Coverage for `SpotlightQuery` — the `NSMetadataQuery` gather/observer/timeout wrapper that
/// `SmartFolderService.runQuery` now drives. Standalone `XCTestCase` (see `SmartFolderQueryTests`
/// precedent), no wiring into `WilesAutomatedXCTestCase.swift`.
///
/// Only proves the async contract: `run()` completes with a well-formed `[String]`, and `cancel()`
/// resolves an in-flight `run()` to `[]`. Doesn't assert non-empty results — Spotlight's cold-start
/// latency is independent of whether a path is indexed, so that would be flaky.
@MainActor
final class SpotlightQueryTests: XCTestCase {
    func testRunCompletesWithFileSystemPaths() async {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let predicate = NSPredicate(format: "kMDItemFSName ==[cd] %@", "*Desktop*")
        let query = SpotlightQuery(predicate: predicate, searchScopes: [home])

        let paths = await query.run()
        XCTAssertTrue(paths.allSatisfy { $0.hasPrefix("/") })
    }

    func testCancelResolvesInFlightRunToEmpty() async {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let predicate = NSPredicate(format: "kMDItemFSName ==[cd] %@", "*\(UUID().uuidString)*")
        let query = SpotlightQuery(predicate: predicate, searchScopes: [home])

        let runTask = Task { await query.run() }
        try? await Task.sleep(for: .milliseconds(50))
        query.cancel()
        let paths = await runTask.value
        XCTAssertEqual(paths, [])
    }
}
