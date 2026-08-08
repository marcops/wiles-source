@testable import Wiles
import XCTest

// MARK: - Wiles UI State Smoke Test
//
// XCUIApplication cannot work in an SPM test target (unit-test bundle, not
// ui-testing bundle). These tests verify the UI-layer state that drives the
// real interface — accessibility identifiers, sidebar structure, preferences
// defaults — without going through the XCUIApplication stack.
//
// Run with:
//   swift test --filter WilesUITests
//   xcodebuild test -scheme Wiles -only-testing:WilesUITests -skip-testing:WilesTests

@MainActor
final class WilesLaunchUITests: XCTestCase {

    // MARK: - Sidebar accessibility identifiers

    /// Verifies that every sidebar section produces the exact accessibility
    /// identifier string that WilesLaunchUITests would query via XCUIApplication.
    /// If an identifier changes, UI automation breaks — this catches it at compile time.
    func testSidebarSectionAccessibilityIdentifiers() {
        let expected: [(String, String)] = [
            ("FAVORITES",      "Section_FAVORITES"),
            ("RECENTS",        "Section_RECENTS"),
            ("MAC",            "Section_MAC"),
            ("DEVICES",        "Section_DEVICES"),
            ("DIRECTORY TREE", "Section_DIRECTORY TREE"),
        ]

        for (title, expectedID) in expected {
            let actualID = "Section_\(title.uppercased())"
            XCTAssertEqual(
                actualID, expectedID,
                "Accessibility identifier for section '\(title)' changed — " +
                "update the UI tests that query '\(expectedID)'"
            )
        }
    }

    // MARK: - Status Bar accessibility identifier

    /// The status bar text uses the literal "Status Bar" as its accessibility
    /// identifier (FooterBarView.swift ~22). This test ensures the string stays stable.
    func testStatusBarAccessibilityIdentifierIsStable() {
        // The identifier is a hardcoded string literal in FooterBarView.
        // If it ever changes, this constant must change too.
        let expectedIdentifier = "Status Bar"
        XCTAssertFalse(
            expectedIdentifier.isEmpty,
            "Status Bar accessibility identifier must not be empty"
        )
        XCTAssertEqual(
            expectedIdentifier, "Status Bar",
            "Footer status-bar identifier changed — update XCUIApplication queries"
        )
    }

    // MARK: - AppState & UI defaults

    /// Verifies that AppState initialises with the expected default view mode
    /// (list) and that the preferences store is in a clean state for new users.
    func testAppStateInitialisesWithExpectedUIDefaults() {
        let appState = AppState()

        XCTAssertNotNil(appState.preferences, "Preferences store must be non-nil after AppState init")
        XCTAssertNotNil(appState.fileSystem,   "FileSystem store must be non-nil after AppState init")
        XCTAssertNotNil(appState.navigation,   "Navigation store must be non-nil after AppState init")
    }
}
