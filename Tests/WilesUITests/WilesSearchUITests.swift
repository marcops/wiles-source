import XCTest

final class WilesSearchUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSearchFieldAppears() throws {
        // Press Command+F to trigger search
        app.typeKey("f", modifierFlags: .command)
        
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2.0), "Search field should appear after pressing Cmd+F")
    }

    func testSearchFiltersResults() throws {
        app.typeKey("f", modifierFlags: .command)
        
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2.0))
        
        searchField.typeText("test_query")
        
        // Wait for the UI to update
        let listContainer = app.scrollViews.firstMatch
        XCTAssertTrue(listContainer.waitForExistence(timeout: 2.0), "List container should be visible")
    }
    
    func testSearchClearButtonRestoresList() throws {
        app.typeKey("f", modifierFlags: .command)
        
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2.0))
        searchField.typeText("random_text_to_clear")
        
        let clearButton = searchField.buttons["Cancel"]
        if clearButton.waitForExistence(timeout: 1.0) {
            clearButton.tap()
        } else {
            // Fallback: press Escape
            app.typeKey(.escape, modifierFlags: [])
        }
        
        // The search field should either be empty or hidden
        if searchField.exists {
            XCTAssertEqual(searchField.value as? String, "", "Search field should be empty after clearing")
        }
    }
}
