import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `BatchRenameModeTests.run()` (see
/// `BatchRenameModeTests.swift`). Not registered in `WilesAutomatedXCTestCase.swift` to avoid
/// churning that shared wrapper file; same precedent already used by `SortOptionTestsCase.swift`.
@MainActor
final class BatchRenameModeTestsCase: XCTestCase {
    func testBatchRenameMode() {
        BatchRenameModeTests.run()
    }
}
