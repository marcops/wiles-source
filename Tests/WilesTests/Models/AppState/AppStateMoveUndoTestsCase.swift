import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `AppStateMoveUndoTests.run()` (finding HM-146), same
/// precedent as `SortOptionTestsCase.swift`.
@MainActor
final class AppStateMoveUndoTestsCase: XCTestCase {
    func testAppStateMoveUndo() async {
        await AppStateMoveUndoTests.run()
    }
}
