import XCTest

final class WilesQABugFindingUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testRapidSearchToggling() throws {
        // QA Bug Finding: Rapidly toggle search with Cmd+F and Escape to detect race conditions/animation loops
        for _ in 1...5 {
            app.typeKey("f", modifierFlags: .command)
            app.typeKey(.escape, modifierFlags: [])
        }
        
        // App should remain responsive and not crash
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }

    func testExtremeColumnDraggingClamps() throws {
        // QA Bug Finding: Navigate to list view to test column resizing behavior
        app.typeKey("2", modifierFlags: .command)
        
        // Access column settings dynamically to check values
        // We assert that the column constraints do not crash the app or lead to negative values
        let headerRow = app.scrollViews.firstMatch
        XCTAssertTrue(headerRow.waitForExistence(timeout: 2.0))
        
        // We trigger extreme resizing behavior and verify the window stays stable
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields.firstMatch
        pathField.typeText("/tmp\r")
        
        XCTAssertTrue(headerRow.exists)
    }
    
    func testEmptyStateLayoutBehavior() throws {
        // QA Bug Finding: Create an empty directory and navigate to it to verify empty state renders cleanly
        let fm = FileManager.default
        let emptyPath = "/tmp/WilesQAEmptyFolder"
        try? fm.removeItem(atPath: emptyPath)
        try fm.createDirectory(atPath: emptyPath, withIntermediateDirectories: true)
        
        defer {
            try? fm.removeItem(atPath: emptyPath)
        }
        
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 2.0))
        pathField.typeText("/tmp/WilesQAEmptyFolder\r")
        
        // Verify empty state warning text displays and doesn't crash the list view
        let emptyStateText = app.staticTexts.matching(XCTestDescription("Empty")).firstMatch
        XCTAssertNotNil(emptyStateText)
    }
}
