import XCTest
@testable import Wiles

/// HM-288: `FileMenuCommands`' plain-key destructive items (Space → Quick Look, Delete → Trash)
/// must be disabled whenever a text field owns focus, using the same signal `EditMenuCommands`
/// already uses to reroute ⌘X/⌘C/⌘V/⌘A. `MenuTextEditingState.isActive` is that shared, pure signal.
final class MenuTextEditingStateTests: XCTestCase {
    func testNothingEditing() {
        XCTAssertFalse(MenuTextEditingState.isActive(
            isTextFieldEditingActive: false, isSearching: false, liveFirstResponderIsText: false))
        XCTAssertFalse(MenuTextEditingState.isActive(
            isTextFieldEditingActive: nil, isSearching: false, liveFirstResponderIsText: false))
    }

    func testRenameFieldOrPathBarActive() {
        XCTAssertTrue(MenuTextEditingState.isActive(
            isTextFieldEditingActive: true, isSearching: false, liveFirstResponderIsText: false))
    }

    func testHeaderSearchActive() {
        XCTAssertTrue(MenuTextEditingState.isActive(
            isTextFieldEditingActive: false, isSearching: true, liveFirstResponderIsText: false))
    }

    func testLiveFirstResponderIsSheetTextField() {
        XCTAssertTrue(MenuTextEditingState.isActive(
            isTextFieldEditingActive: false, isSearching: false, liveFirstResponderIsText: true))
    }

    func testAnySignalWins() {
        XCTAssertTrue(MenuTextEditingState.isActive(
            isTextFieldEditingActive: true, isSearching: true, liveFirstResponderIsText: true))
    }
}
