import XCTest

// MARK: - Wiles Core UI Smoke Test

//
// This test uses XCUIApplication() — it launches Wiles.app, takes control of
// the screen and verifies the core UI shell is present and interactive.
//
// ✅ Run from Xcode: open Package.swift → Product → Test (⌘U)
//    Xcode configures the host app automatically. You will see macOS ask for
//    Accessibility permission on first run and the screen will be controlled.
//
// ❌ NOT run via `swift test` or bare `xcodebuild` — SPM produces a unit-test
//    bundle, not a ui-testing bundle. validate.sh already skips WilesUITests.
//
// Accessibility identifiers relied on (must remain stable):
//   "Section_FAVORITES"   SidebarView.swift ~184
//   "Status Bar"          FooterBarView.swift ~22

@MainActor
final class WilesLaunchUITests: XCTestCase {
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Smoke test: launch + core shell

    /// Launches Wiles, waits for the main window, then verifies:
    ///   1. The FAVORITES sidebar section exists and is hittable.
    ///   2. The footer status-bar text exists.
    ///   3. Clicking FAVORITES (collapse/expand) does not crash.
    ///
    /// All assertions are unconditional — no silent `if element.exists` guards.
    func testAppLaunchesAndCoreShellIsVisible() {
        // 1. Main window must appear within 5 s.
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 5.0),
            "Wiles main window did not appear within 5 seconds")

        // 2. FAVORITES sidebar section must be present.
        //    id: "Section_FAVORITES" — SidebarView.swift ~184
        //    `.firstMatch` on the identifier query (not the bare subscript) because SwiftUI can
        //    transiently keep two "Section_FAVORITES" elements alive in the accessibility snapshot
        //    right after launch (old + new render of the section header during initial layout).
        //    The bare `app.buttons["..."]` resolves to a single-element query that throws
        //    "Multiple matching elements found" once that happens; `.firstMatch` waits for/returns
        //    whichever one currently resolves, which is what both waitForExistence and isHittable
        //    below actually need.
        let favorites = app.buttons.matching(identifier: "Section_FAVORITES").firstMatch
        XCTAssertTrue(
            favorites.waitForExistence(timeout: 3.0),
            "Sidebar FAVORITES section (id='Section_FAVORITES') not found — " +
                "sidebar failed to render or the accessibility identifier changed")

        // 3. FAVORITES must be hittable (not obscured).
        XCTAssertTrue(
            favorites.isHittable,
            "Sidebar FAVORITES section exists but is not hittable")

        // 4. Footer status-bar text must be present.
        //    id: "Status Bar" — FooterBarView.swift ~22
        let statusBar = app.staticTexts["Status Bar"]
        XCTAssertTrue(
            statusBar.waitForExistence(timeout: 3.0),
            "Footer status-bar text (id='Status Bar') not found — " +
                "footer failed to render or the accessibility identifier changed")

        // 5. Click FAVORITES — button must survive (toggles collapse state).
        favorites.click()
        XCTAssertTrue(
            favorites.waitForExistence(timeout: 2.0),
            "FAVORITES button disappeared after click — unexpected crash or removal")
    }
}
