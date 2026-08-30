import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `FolderNodeDirectoryTreeTests.run()` (see
/// `FolderNodeDirectoryTreeTests.swift`), mirroring `BoundedFolderNodeCacheTestsCase.swift`.
@MainActor
final class FolderNodeDirectoryTreeTestsCase: XCTestCase {
    func testFolderNodeDirectoryTree() async {
        await FolderNodeDirectoryTreeTests.run()
    }
}
