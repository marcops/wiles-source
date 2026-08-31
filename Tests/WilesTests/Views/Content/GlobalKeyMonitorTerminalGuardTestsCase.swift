import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `GlobalKeyMonitorTerminalGuardTests.run()` — not registered
/// in `WilesAutomatedXCTestCase.swift` to avoid churning that shared wrapper file (same precedent
/// as `SortOptionTestsCase.swift`).
@MainActor
final class GlobalKeyMonitorTerminalGuardTestsCase: XCTestCase {
    func testGlobalKeyMonitorTerminalGuard() {
        GlobalKeyMonitorTerminalGuardTests.run()
    }
}
