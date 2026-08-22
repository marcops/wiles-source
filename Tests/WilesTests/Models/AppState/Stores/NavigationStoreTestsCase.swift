import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `NavigationStoreTests.run()` (see
/// `NavigationStoreTests.swift`), mirroring `ListColumnSettingsTestsCase.swift`.
@MainActor
final class NavigationStoreTestsCase: XCTestCase {
    func testNavigationStore() async {
        await NavigationStoreTests.run()
    }
}
