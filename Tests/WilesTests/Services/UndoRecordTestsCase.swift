import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `UndoRecordTests.run()` (see `UndoRecordTests.swift`),
/// mirroring `ListColumnSettingsTestsCase.swift`.
@MainActor
final class UndoRecordTestsCase: XCTestCase {
    func testUndoRecord() {
        UndoRecordTests.run()
    }
}
