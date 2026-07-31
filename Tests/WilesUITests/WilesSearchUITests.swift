import XCTest

final class WilesSearchUITests: XCTestCase {
    
    private let testDirPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("WilesUITestSearch")
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // 1. Setup a test directory with specific files for testing search
        let fm = FileManager.default
        if fm.fileExists(atPath: testDirPath) {
            try fm.removeItem(atPath: testDirPath)
        }
        try fm.createDirectory(atPath: testDirPath, withIntermediateDirectories: true)
        
        let targetFile = testDirPath + "/WilesUniqueTargetFile.txt"
        let decoyFile = testDirPath + "/WilesDecoyFile.txt"
        try "Target".write(toFile: targetFile, atomically: true, encoding: .utf8)
        try "Decoy".write(toFile: decoyFile, atomically: true, encoding: .utf8)
        
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try? FileManager.default.removeItem(atPath: testDirPath)
    }

    func testCompleteSearchFlow() throws {
        // Step 1: Navigate to the test directory using Cmd+L (Focus Path Field)
        app.typeKey("l", modifierFlags: .command)
        
        // Wait for the path text field to be focused
        let textFields = app.textFields
        XCTAssertTrue(textFields.element.waitForExistence(timeout: 2.0))
        
        // Clear whatever is there and type the test path
        let pathField = textFields.firstMatch
        pathField.typeText("\(testDirPath)\r")
        
        // Verify both files are visible initially
        let targetText = app.staticTexts["WilesUniqueTargetFile.txt"]
        let decoyText = app.staticTexts["WilesDecoyFile.txt"]
        XCTAssertTrue(targetText.waitForExistence(timeout: 3.0), "Target file should be visible before search")
        XCTAssertTrue(decoyText.waitForExistence(timeout: 3.0), "Decoy file should be visible before search")
        
        // Step 2: Trigger Search using Cmd+F
        app.typeKey("f", modifierFlags: .command)
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2.0), "Search field must appear")
        
        // Step 3: Type search query
        searchField.typeText("UniqueTarget")
        
        // Step 4: Verify search filters the results!
        // Target file must remain visible.
        XCTAssertTrue(targetText.exists, "Target file should still be visible because it matches the search")
        // Decoy file MUST disappear.
        XCTAssertFalse(decoyText.exists, "Decoy file should be filtered out by the search query")
        
        // Step 5: Verify Right Click works on the filtered search result (Ghost Mouse right click!)
        targetText.rightClick()
        
        let contextMenu = app.menus.firstMatch
        XCTAssertTrue(contextMenu.waitForExistence(timeout: 2.0), "Context menu must appear when right clicking a search result")
        
        // Step 6: Clear search (Cmd+F and Escape)
        app.typeKey(.escape, modifierFlags: []) // Closes context menu
        app.typeKey("f", modifierFlags: .command)
        
        let clearButton = searchField.buttons["Cancel"]
        if clearButton.waitForExistence(timeout: 1.0) {
            clearButton.tap()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
        
        // Decoy file should reappear
        XCTAssertTrue(decoyText.waitForExistence(timeout: 2.0), "Decoy file should reappear after clearing the search")
    }
}
