import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `AutoOrganizationRuleTests.run()` (see
/// `AutoOrganizationRuleTests.swift`). Not registered in `WilesAutomatedXCTestCase.swift` to avoid
/// churning that shared wrapper file; same precedent already used by `SortOptionTestsCase.swift`.
@MainActor
final class AutoOrganizationRuleTestsCase: XCTestCase {
    func testAutoOrganizationRule() {
        AutoOrganizationRuleTests.run()
    }
}
