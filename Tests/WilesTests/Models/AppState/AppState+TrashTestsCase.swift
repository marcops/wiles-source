import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `AppStateTrashTests.run()` (see `AppState+TrashTests.swift`).
/// Not registered in `WilesAutomatedXCTestCase.swift`, mirroring the `ListColumnSettingsTestsCase.swift`
/// precedent for new suites.
@MainActor
final class AppStateTrashTestsCase: XCTestCase {
    func testAppStateTrash() async {
        await AppStateTrashTests.run()
    }
}
