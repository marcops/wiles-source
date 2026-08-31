import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `FolderWatcherTests.run()` (finding ML-103), same precedent
/// as `SortOptionTestsCase.swift`.
@MainActor
final class FolderWatcherTestsCase: XCTestCase {
    func testFolderWatcher() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "SKIP-CI-SLOW: real DispatchSource timing")
        await FolderWatcherTests.run()
    }
}
