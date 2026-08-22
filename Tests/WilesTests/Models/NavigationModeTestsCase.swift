import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `NavigationModeTests.run()` (see `NavigationModeTests.swift`),
/// mirroring `ListColumnSettingsTestsCase.swift`.
@MainActor
final class NavigationModeTestsCase: XCTestCase {
    func testNavigationMode() {
        NavigationModeTests.run()
    }
}
