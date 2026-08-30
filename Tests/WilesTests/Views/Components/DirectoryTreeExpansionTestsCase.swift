import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `DirectoryTreeExpansionTests.run()` (see
/// `DirectoryTreeExpansionTests.swift`), mirroring `BoundedFolderNodeCacheTestsCase.swift`.
@MainActor
final class DirectoryTreeExpansionTestsCase: XCTestCase {
    func testDirectoryTreeExpansion() {
        DirectoryTreeExpansionTests.run()
    }
}
