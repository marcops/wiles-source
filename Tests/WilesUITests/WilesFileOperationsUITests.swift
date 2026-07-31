import XCTest

final class WilesFileOperationsUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        
        let fm = FileManager.default
        let opPath = "/tmp/WilesFileOperationsUITests"
        if fm.fileExists(atPath: opPath) {
            try fm.removeItem(atPath: opPath)
        }
        try fm.createDirectory(atPath: opPath, withIntermediateDirectories: true)
        
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try? FileManager.default.removeItem(atPath: "/tmp/WilesFileOperationsUITests")
    }

    func testCreateNewFolder() throws {
        // Navigate to temp dir
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 2.0))
        pathField.typeText("/tmp/WilesFileOperationsUITests\r")
        
        // Trigger New Folder via shortcut Shift+Cmd+N
        app.typeKey("n", modifierFlags: [.command, .shift])
        
        // Wait for sheet dialog and type directory name
        let sheetTextField = app.sheets.textFields.firstMatch
        XCTAssertTrue(sheetTextField.waitForExistence(timeout: 2.0))
        
        // Clear default name and type ours
        sheetTextField.typeText("\u{8}\u{8}\u{8}\u{8}\u{8}\u{8}\u{8}\u{8}\u{8}\u{8}MyNewFolder\r")
        
        // Verify folder is created in UI
        let newFolderText = app.staticTexts["MyNewFolder"]
        XCTAssertTrue(newFolderText.waitForExistence(timeout: 3.0), "MyNewFolder should appear in the folder list")
    }

    func testDeleteFile() throws {
        // Navigate to temp dir
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 2.0))
        pathField.typeText("/tmp/WilesFileOperationsUITests\r")
        
        // Pre-create a folder to delete
        let fm = FileManager.default
        try fm.createDirectory(atPath: "/tmp/WilesFileOperationsUITests/DeleteMe", withIntermediateDirectories: true)
        
        let targetText = app.staticTexts["DeleteMe"]
        XCTAssertTrue(targetText.waitForExistence(timeout: 3.0))
        
        // Click to select the item
        targetText.click()
        
        // Trigger Delete
        app.typeKey(.delete, modifierFlags: [.command])
        
        // Verify item is removed from the UI list
        let exists = targetText.waitForExistence(timeout: 2.0)
        XCTAssertFalse(exists, "DeleteMe should be removed from the UI list")
    }
}
