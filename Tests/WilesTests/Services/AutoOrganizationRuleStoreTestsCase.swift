import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `AutoOrganizationRuleStoreTests.run()` (see
/// `AutoOrganizationRuleStoreTests.swift`), mirroring `ListColumnSettingsTestsCase.swift`.
@MainActor
final class AutoOrganizationRuleStoreTestsCase: XCTestCase {
    func testAutoOrganizationRuleStore() {
        AutoOrganizationRuleStoreTests.run()
    }
}
