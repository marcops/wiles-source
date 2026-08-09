import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `ListColumnSettingsTests.run()` (see
/// `ListColumnSettingsTests.swift`). Not registered in `WilesAutomatedXCTestCase.swift` to avoid
/// churning that shared wrapper file; same precedent already used by `SortOptionTestsCase.swift`.
@MainActor
final class ListColumnSettingsTestsCase: XCTestCase {
    func testListColumnSettings() {
        ListColumnSettingsTests.run()
    }
}
