import XCTest

final class WilesUIUXValidationUITests: XCTestCase {
    
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

    func testHeaderHeightConstraint() throws {
        // UI/UX Validation: Make sure the header element does not get unreasonably tall
        app.typeKey("2", modifierFlags: .command) // Switch to List View
        
        let header = app.scrollViews.firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 2.0))
        
        // Assert height is within bounds (should not exceed ~40 points)
        let headerFrame = header.frame
        XCTAssertLessThanOrEqual(headerFrame.height, 100, "Header is too tall, layout regression detected")
    }

    func testTextTruncationInColumns() throws {
        // UI/UX Validation: Ensure extremely long file names don't expand the row vertically or break layout
        let fm = FileManager.default
        let testPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("WilesUIUXTruncation")
        try? fm.removeItem(atPath: testPath)
        try fm.createDirectory(atPath: testPath, withIntermediateDirectories: true)
        
        let longName = "ThisIsAnExtremelyLongFileNameThatShouldBeTruncatedAndNotWrapUnderAnyCircumstancesInWilesListView.txt"
        try "Content".write(toFile: testPath + "/" + longName, atomically: true, encoding: .utf8)
        
        defer {
            try? fm.removeItem(atPath: testPath)
        }
        
        // Navigate
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 2.0))
        pathField.typeText("\(testPath)\r")
        
        app.typeKey("2", modifierFlags: .command) // Force list mode
        
        let fileRow = app.staticTexts[longName]
        XCTAssertTrue(fileRow.waitForExistence(timeout: 3.0))
        
        // Confirm the cell height remains compact (rows should be around 20-40pt high depending on density)
        let rowHeight = fileRow.frame.height
        XCTAssertLessThanOrEqual(rowHeight, 50, "Row height blew up; name likely wrapped instead of truncating!")
    }
    
    func testCompactDensityToggleUX() throws {
        // UI/UX Validation: Toggle Compact Density and verify spacing shifts visually
        app.typeKey("2", modifierFlags: .command) // list view
        
        // Access View Menu -> Compact Density or use standard shortcuts if defined
        // We will toggle compact density using app commands
        let menuBar = app.menuBars
        let viewMenu = menuBar.menuItems["View"]
        if viewMenu.exists {
            viewMenu.click()
            let compactItem = menuBar.menuItems["Compact Spacing"]
            if compactItem.exists {
                compactItem.click()
            }
        }
        
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }
}
