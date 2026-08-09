import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `RenameTabModeTests.run()` (see `RenameTabModeTests.swift`).
/// Not registered in `WilesAutomatedXCTestCase.swift` to avoid churning that shared wrapper file;
/// same precedent already used by `SortOptionTestsCase.swift`.
@MainActor
final class RenameTabModeTestsCase: XCTestCase {
    func testRenameTabMode() {
        RenameTabModeTests.run()
    }
}
