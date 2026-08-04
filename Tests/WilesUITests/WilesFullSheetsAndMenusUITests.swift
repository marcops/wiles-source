import XCTest

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

        // View Menu Interaction
        let viewMenu = menuBar.menuItems["View"]
        if viewMenu.exists {
            viewMenu.click()
            let reloadItem = menuBar.menuItems["Reload"]
            if reloadItem.exists { reloadItem.click() }
        }

        // Window Menu Interaction
        let windowMenu = menuBar.menuItems["Window"]
        if windowMenu.exists {
            windowMenu.click()
        }
    }

    func testShortcutNavigationKeyBindings() throws {
        // Command + 1: Grid Mode
        app.typeKey("1", modifierFlags: .command)

        // Command + 2: List Mode
        app.typeKey("2", modifierFlags: .command)

        // Command + 3: Column Mode
        app.typeKey("3", modifierFlags: .command)

        // Command + F: Search Field Focus
        app.typeKey("f", modifierFlags: .command)

        // Command + L: Path Bar Focus
        app.typeKey("l", modifierFlags: .command)

        // Escape: Clear Focus / Dismiss Search
        app.typeKey(.escape, modifierFlags: [])
    }
}
