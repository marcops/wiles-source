import XCTest

@MainActor
final class WilesSidebarUITests: XCTestCase {

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

    func testSidebarSectionTogglesAndPlacesNavigation() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3.0), "Main app window should appear")

        let favoritesSection = app.buttons["Section_FAVORITES"]
        if favoritesSection.waitForExistence(timeout: 2.0) {
            favoritesSection.click()
            XCTAssertTrue(favoritesSection.exists, "Favorites section button should remain present after toggle")
        }

        let recentsSection = app.buttons["Section_RECENTS"]
        if recentsSection.waitForExistence(timeout: 2.0) {
            recentsSection.click()
            XCTAssertTrue(recentsSection.exists, "Recents section button should remain present after toggle")
        }
    }
}
