import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `HeaderCenterModeTests.run()` (see `HeaderCenterModeTests.swift`),
/// mirroring `NavigationModeTestsCase.swift`.
@MainActor
final class HeaderCenterModeTestsCase: XCTestCase {
    func testHeaderCenterMode() {
        HeaderCenterModeTests.run()
    }
}
