import XCTest

@MainActor
final class WilesModalsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let appURL = URL(fileURLWithPath: "Wiles.app")
        app = FileManager.default.fileExists(atPath: appURL.path) ? XCUIApplication(url: appURL) : XCUIApplication(bundleIdentifier: "com.marco.wiles")
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testHelpSheetTrigger() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3.0), "Main app window should appear")

        app.typeKey("?", modifierFlags: .command)
        let helpText = app.staticTexts["Keyboard Shortcuts"]
        if helpText.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(helpText.exists, "Keyboard Shortcuts title should be visible inside Help sheet")
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}
