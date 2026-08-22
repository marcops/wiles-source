import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `BoundedFolderNodeCacheTests.run()` (see
/// `BoundedFolderNodeCacheTests.swift`). Not registered in `WilesAutomatedXCTestCase.swift` to
/// avoid churning that shared wrapper file; same precedent already used by
/// `ListColumnSettingsTestsCase.swift`.
@MainActor
final class BoundedFolderNodeCacheTestsCase: XCTestCase {
    func testBoundedFolderNodeCache() {
        BoundedFolderNodeCacheTests.run()
    }
}
