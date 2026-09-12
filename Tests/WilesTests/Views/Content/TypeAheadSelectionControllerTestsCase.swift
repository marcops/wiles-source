import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `TypeAheadSelectionControllerTests.run()` — not registered
/// in `WilesAutomatedXCTestCase.swift` to avoid churning that shared wrapper file (same precedent
/// as `GlobalKeyMonitorTerminalGuardTestsCase.swift`).
@MainActor
final class TypeAheadSelectionControllerTestsCase: XCTestCase {
    func testTypeAheadSelectionController() {
        TypeAheadSelectionControllerTests.run()
    }
}
