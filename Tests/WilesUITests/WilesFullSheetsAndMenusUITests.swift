import XCTest

@MainActor
final class WilesFullSheetsAndMenusUITests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional - standard XCTest lifecycle property, set in setUp/tearDown
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let run = self.testRun, !run.hasSucceeded {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure_Screenshot_Sheets"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app = nil
    }

    func testSystemMenuNavigationAndToolbars() throws {
        let menuBar = app.menuBars
        let viewMenu = menuBar.menuItems["View"]
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 2.0), "View menu should exist")
        viewMenu.click()

        let reloadItem = menuBar.menuItems["Reload"]
        XCTAssertTrue(reloadItem.waitForExistence(timeout: 2.0), "Reload item should exist in View menu")
        reloadItem.click()

        let windowMenu = menuBar.menuItems["Window"]
        XCTAssertTrue(windowMenu.waitForExistence(timeout: 2.0), "Window menu should exist")
        windowMenu.click()
    }

    func testShortcutNavigationKeyBindings() throws {
        app.typeKey("1", modifierFlags: .command)
        app.typeKey("2", modifierFlags: .command)
        app.typeKey("3", modifierFlags: .command)
        app.typeKey("f", modifierFlags: .command)
        app.typeKey("l", modifierFlags: .command)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testViewModeToolbarButtons() throws {
        let gridBtn = app.buttons["ViewModeGrid"]
        let listBtn = app.buttons["ViewModeList"]
        let columnBtn = app.buttons["ViewModeColumn"]

        XCTAssertTrue(gridBtn.waitForExistence(timeout: 2.0), "ViewModeGrid button should exist")
        gridBtn.click()

        XCTAssertTrue(listBtn.waitForExistence(timeout: 2.0), "ViewModeList button should exist")
        listBtn.click()

        XCTAssertTrue(columnBtn.waitForExistence(timeout: 2.0), "ViewModeColumn button should exist")
        columnBtn.click()
    }

    func testSidebarSectionCollapseExpand() throws {
        let favoritesBtn = app.buttons["Section_FAVORITES"]
        let recentsBtn = app.buttons["Section_RECENTS"]

        if favoritesBtn.exists {
            favoritesBtn.click()
        }
        if recentsBtn.exists {
            recentsBtn.click()
        }
    }

    func testOperationsPopoverToggle() throws {
        let popoverButton = app.buttons["OperationsProgressButton"]
        if popoverButton.exists {
            popoverButton.click()
        }
    }
}
