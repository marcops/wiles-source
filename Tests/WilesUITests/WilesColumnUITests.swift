import XCTest

@MainActor
final class WilesColumnUITests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional - standard XCTest lifecycle property, set in setUp/tearDown
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

    func testHorizontalScrollbarAppearsWhenColumnsExceedWindow() throws {
        app.typeKey("2", modifierFlags: .command)

        let scrollViewsQuery = app.scrollViews
        XCTAssertTrue(scrollViewsQuery.element.waitForExistence(timeout: 2.0), "Scroll view should exist in list mode")

        let nameText = app.staticTexts["Name"]
        XCTAssertTrue(nameText.waitForExistence(timeout: 2.0), "Name column header should exist")
        XCTAssertTrue(nameText.isHittable, "Name column header should be hittable")
    }

    func testToggleColumnVisibility() throws {
        app.typeKey("2", modifierFlags: .command)

        let headerRow = app.scrollViews.firstMatch
        XCTAssertTrue(headerRow.waitForExistence(timeout: 2.0), "Header row scroll view should exist")

        headerRow.rightClick()

        let menu = app.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 2.0), "Context menu should appear for column visibility")

        let dateCreatedItem = menu.menuItems["Date Created"]
        XCTAssertTrue(dateCreatedItem.waitForExistence(timeout: 2.0), "Date Created menu item should exist in context menu")
        dateCreatedItem.click()
    }
}
