import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `WilesErrorTests.run()` (see `WilesErrorTests.swift`). Not
/// registered in `WilesAutomatedXCTestCase.swift` to avoid churning that shared wrapper file; same
/// precedent already used by `SortOptionTestsCase.swift`.
@MainActor
final class WilesErrorTestsCase: XCTestCase {
    func testWilesError() {
        WilesErrorTests.run()
    }
}
