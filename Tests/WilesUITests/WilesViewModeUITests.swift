import XCTest

final class WilesViewModeUITests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional - standard XCTest lifecycle property, set in setUp/tearDown
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

    func testSwitchViewModes() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 2.0), "Main window should exist")

        let switcherButton = app.buttons.matching(identifier: "View Mode").firstMatch
        if switcherButton.exists {
            switcherButton.click()
        }

        let menuBar = app.menuBars
        let viewMenu = menuBar.menuItems["View"]
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 2.0), "View menu should exist in menu bar")
        viewMenu.click()

        let gridViewItem = menuBar.menuItems["Grid View"]
        XCTAssertTrue(gridViewItem.waitForExistence(timeout: 2.0), "Grid View menu item should exist")
        gridViewItem.click()
    }

    func testToggleStatusBar() throws {
        let footer = app.staticTexts.matching(identifier: "Status Bar").firstMatch
        let initialExists = footer.exists

        app.typeKey("/", modifierFlags: .command)

        let postToggleExists = footer.waitForExistence(timeout: 1.0)
        XCTAssertNotEqual(initialExists, postToggleExists, "Status bar visibility should toggle state after Cmd+/ shortcut")
    }
}
