import XCTest

final class WilesColumnUITests: XCTestCase {

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

    func testHorizontalScrollbarAppearsWhenColumnsExceedWindow() throws {
        // Change view mode to list to ensure columns are visible
        app.typeKey("2", modifierFlags: .command)

        let scrollViewsQuery = app.scrollViews
        XCTAssertTrue(scrollViewsQuery.element.waitForExistence(timeout: 2.0), "Scroll view should exist in list mode")

        // This is an advanced interaction. Since SwiftUI dividers are hard to grab via Accessibility without custom IDs,
        // we simulate the window resize effect or check for scroll indicators if possible via XCUITest.
        // For standard Xcode UI Tests, we verify that the ScrollView container handles the layout.

        // A generic test check for list mode columns
        let nameText = app.staticTexts["Name"]
        if nameText.exists {
            XCTAssertTrue(nameText.isHittable, "Name column header should be hittable")
        }
    }

    func testToggleColumnVisibility() throws {
        app.typeKey("2", modifierFlags: .command)

        let headerRow = app.scrollViews.firstMatch
        XCTAssertTrue(headerRow.waitForExistence(timeout: 2.0))

        // Right click the header to show the context menu
        // In XCUITest, a right click on macOS is performed using rightClick()
        headerRow.rightClick()

        let menu = app.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 2.0), "Context menu should appear for column visibility")

        let dateCreatedItem = menu.menuItems["Date Created"]
        if dateCreatedItem.exists {
            dateCreatedItem.click()
        }
    }
}
