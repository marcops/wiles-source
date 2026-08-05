import XCTest

@MainActor
final class WilesThemeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testThemeAppearanceShortcutToggles() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3.0), "Main app window should appear")

        app.typeKey("t", modifierFlags: [.command, .option])
        XCTAssertTrue(window.exists, "Main app window should remain responsive after theme toggle shortcut")
    }
}
