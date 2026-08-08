import XCTest

// MARK: - Wiles Launch & Core UI Smoke Test
//
// Purpose: verify that the real Wiles.app (com.marco.wiles) launches correctly
// and that its core UI shell is present and interactive.
//
// How to run:
//   xcodebuild test -scheme Wiles -testPlan WilesUITests   (from an Xcode project)
//   — OR open in Xcode and hit ⌘U on this file.
//
// This test is NOT run by `swift test` (XCUITest requires an Xcode runner with a
// target app; SPM's harness does not provide one).  The validate.sh script skips
// this target intentionally for that reason.
//
// Accessibility identifiers relied on (all must remain stable):
//   "Section_FAVORITES"     SidebarView.swift ~184
//   "Status Bar"            FooterBarView.swift ~22

@MainActor
final class WilesLaunchUITests: XCTestCase {

    // Standard XCTest lifecycle property — initialised in setUp(), cleared in tearDown().
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        // Launch by bundle ID so the test targets the installed/built Wiles.app
        // and not an arbitrary process.
        app = XCUIApplication(bundleIdentifier: "com.marco.wiles")
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil
        try await super.tearDown()
    }

    // MARK: - Smoke test: app window & core shell

    /// Verifies that Wiles launches, shows its main window, and renders the two
    /// UI landmarks we depend on for every other UI test:
    ///   1. The FAVORITES sidebar section (proves the sidebar rendered).
    ///   2. The status-bar text element (proves the footer rendered).
    ///
    /// Every assertion is unconditional — no silent `if element.exists { }` guards.
    func testAppLaunchesAndCoreShellIsVisible() throws {
        // 1. Main window must appear within a generous timeout.
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 5.0),
            "Wiles main window did not appear within 5 seconds"
        )

        // 2. The FAVORITES sidebar section button must exist.
        //    Accessibility identifier: "Section_FAVORITES" (SidebarView.swift ~184)
        let favoritesSection = app.buttons["Section_FAVORITES"]
        XCTAssertTrue(
            favoritesSection.waitForExistence(timeout: 3.0),
            "Sidebar FAVORITES section (id='Section_FAVORITES') was not found — " +
            "sidebar may have failed to render or the accessibility identifier changed"
        )

        // 3. The FAVORITES section button must be hittable (not covered/hidden).
        XCTAssertTrue(
            favoritesSection.isHittable,
            "Sidebar FAVORITES section exists but is not hittable — it may be obscured"
        )

        // 4. The status-bar text element must exist in the footer.
        //    Accessibility identifier: "Status Bar" (FooterBarView.swift ~22)
        let statusBar = app.staticTexts["Status Bar"]
        XCTAssertTrue(
            statusBar.waitForExistence(timeout: 3.0),
            "Footer status-bar text (id='Status Bar') was not found — " +
            "footer may have failed to render or the accessibility identifier changed"
        )

        // 5. Clicking the FAVORITES section must not crash and the button must
        //    remain present afterwards (toggling collapse is the expected behaviour).
        favoritesSection.click()
        XCTAssertTrue(
            favoritesSection.waitForExistence(timeout: 2.0),
            "FAVORITES section button disappeared after clicking — unexpected crash or removal"
        )
    }
}
