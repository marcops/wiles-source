import XCTest

@MainActor
final class WilesInfoModalsUITests: XCTestCase {

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
            attachment.name = "Failure_Screenshot_InfoModals"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app = nil
    }

    /// About Wiles is presented from the app menu ("Wiles" -> "About Wiles").
    func testAboutSheetOpensAndDismisses() throws {
        let menuBar = app.menuBars
        let appMenu = menuBar.menuItems["Wiles"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: 2.0), "App menu 'Wiles' should exist")
        appMenu.click()

        let aboutItem = menuBar.menuItems["About Wiles"]
        XCTAssertTrue(aboutItem.waitForExistence(timeout: 2.0), "About Wiles menu item should exist")
        aboutItem.click()

        let aboutTitle = app.staticTexts["About Wiles"]
        XCTAssertTrue(aboutTitle.waitForExistence(timeout: 2.0), "About sheet title should appear")

        let versionText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Version")).firstMatch
        XCTAssertTrue(versionText.waitForExistence(timeout: 2.0), "About sheet version label should appear")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2.0), "Done button should exist on About sheet")
        doneButton.click()

        XCTAssertFalse(aboutTitle.waitForExistence(timeout: 1.0), "About sheet title should be gone after dismissing")
    }

    /// Help & Shortcuts is presented from the Help menu, and also bound to Cmd+?.
    func testHelpSheetOpensAndDismisses() throws {
        let menuBar = app.menuBars
        let helpMenu = menuBar.menuItems["Help"]
        XCTAssertTrue(helpMenu.waitForExistence(timeout: 2.0), "Help menu should exist")
        helpMenu.click()

        let helpItem = menuBar.menuItems["Wiles Help & Shortcuts"]
        XCTAssertTrue(helpItem.waitForExistence(timeout: 2.0), "Wiles Help & Shortcuts menu item should exist")
        helpItem.click()

        let helpTitle = app.staticTexts["Wiles File Manager"]
        XCTAssertTrue(helpTitle.waitForExistence(timeout: 2.0), "Help sheet title should appear")

        let helpSubtitle = app.staticTexts["Help & Feature Guide"]
        XCTAssertTrue(helpSubtitle.waitForExistence(timeout: 2.0), "Help sheet subtitle should appear")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2.0), "Done button should exist on Help sheet")
        doneButton.click()

        XCTAssertFalse(helpTitle.waitForExistence(timeout: 1.0), "Help sheet title should be gone after dismissing")
    }

    /// Auto-Organization Rules is presented from the Tools menu.
    func testAutoOrganizationSheetOpensAndDismisses() throws {
        let menuBar = app.menuBars
        let toolsMenu = menuBar.menuItems["Tools"]
        XCTAssertTrue(toolsMenu.waitForExistence(timeout: 2.0), "Tools menu should exist")
        toolsMenu.click()

        let autoOrgItem = menuBar.menuItems.matching(NSPredicate(format: "title CONTAINS %@", "Auto-Organization")).firstMatch
        XCTAssertTrue(autoOrgItem.waitForExistence(timeout: 2.0), "Auto-Organization Rules menu item should exist")
        autoOrgItem.click()

        let noRulesTitle = app.staticTexts["No Auto-Organization Rules"]
        let addRuleTitle = app.staticTexts["Add New Rule"]
        XCTAssertTrue(addRuleTitle.waitForExistence(timeout: 2.0), "Auto-Organization sheet 'Add New Rule' section should appear")
        XCTAssertTrue(noRulesTitle.exists || addRuleTitle.exists, "Auto-Organization sheet content should be present")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2.0), "Done button should exist on Auto-Organization sheet")
        doneButton.click()

        XCTAssertFalse(addRuleTitle.waitForExistence(timeout: 1.0), "Auto-Organization sheet content should be gone after dismissing")
    }

    /// Connect to Server is presented from the Go menu, and also bound to Cmd+K.
    func testConnectToServerSheetOpensAndDismisses() throws {
        let menuBar = app.menuBars
        let goMenu = menuBar.menuItems["Go"]
        XCTAssertTrue(goMenu.waitForExistence(timeout: 2.0), "Go menu should exist")
        goMenu.click()

        let connectItem = menuBar.menuItems.matching(NSPredicate(format: "title CONTAINS %@", "Connect to Server")).firstMatch
        XCTAssertTrue(connectItem.waitForExistence(timeout: 2.0), "Connect to Server menu item should exist")
        connectItem.click()

        let connectTitle = app.staticTexts["Connect to Server"]
        XCTAssertTrue(connectTitle.waitForExistence(timeout: 2.0), "Connect to Server sheet title should appear")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2.0), "Cancel button should exist on Connect to Server sheet")
        cancelButton.click()

        XCTAssertFalse(connectTitle.waitForExistence(timeout: 1.0), "Connect to Server sheet title should be gone after dismissing")
    }
}
