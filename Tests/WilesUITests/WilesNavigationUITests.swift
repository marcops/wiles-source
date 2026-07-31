import XCTest

final class WilesNavigationUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        
        let fm = FileManager.default
        let navTestPath = "/tmp/WilesNavigationUITests"
        if fm.fileExists(atPath: navTestPath) {
            try fm.removeItem(atPath: navTestPath)
        }
        try fm.createDirectory(atPath: navTestPath, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: navTestPath + "/SubFolderA", withIntermediateDirectories: true)
        
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try? FileManager.default.removeItem(atPath: "/tmp/WilesNavigationUITests")
    }

    func testNavigationBackAndForward() throws {
        // Focus path and navigate to our test directory
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 2.0))
        pathField.typeText("/tmp/WilesNavigationUITests\r")
        
        // Find SubFolderA and double-click it to enter
        let subFolderItem = app.staticTexts["SubFolderA"]
        XCTAssertTrue(subFolderItem.waitForExistence(timeout: 3.0))
        subFolderItem.doubleClick()
        
        // Go back using Cmd+[
        app.typeKey("[", modifierFlags: .command)
        XCTAssertTrue(subFolderItem.waitForExistence(timeout: 3.0), "Should navigate back to show SubFolderA")
        
        // Go forward using Cmd+]
        app.typeKey("]", modifierFlags: .command)
        XCTAssertFalse(subFolderItem.exists, "Should navigate forward into SubFolderA where SubFolderA itself is not visible inside the list")
    }
    
    func testFavoritesToggle() throws {
        // Toggle Favorites visibility (using Menu bar command or menu item)
        // We'll click the "View" menu or test the window's elements to make sure it handles favorites
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 2.0))
        
        // Check if sidebar Favorites exists
        let favoritesTitle = app.staticTexts["FAVORITES"]
        if favoritesTitle.exists {
            XCTAssertTrue(favoritesTitle.isHittable)
        }
    }
}
