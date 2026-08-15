import XCTest

// MARK: - New Folder inline-rename regression

//
// Real reported bug: "New Folder" (Cmd+Shift+N) created the folder on disk, but the inline
// rename field either never appeared or appeared and closed itself almost immediately, forcing
// the user to manually trigger rename (F2) afterward. Root cause was `refreshCurrentDirectory()`
// (called right after creating the folder) racing the newly-inserted `FileItem` — see
// `AppState.enterRenameForNewlyCreated` for the fix.
//
// ❌ NOT run via `swift test` or bare `xcodebuild` — see WilesLaunchUITests.swift's header comment.
// ✅ Run from Xcode: open Package.swift → Product → Test (⌘U)
//
// Accessibility identifiers relied on (must remain stable):
//   "PathBarTextField"    PathBarView.swift ~54
//   "InlineRenameField"   InlineRenameField.swift ~54

@MainActor
final class NewFolderRenameUITests: XCTestCase {
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var tempDir: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WilesUITest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    /// Navigates to a clean temp folder, triggers "New Folder", then verifies the inline rename
    /// field appears, is still there a moment later (catches the "closes itself immediately"
    /// failure mode), and that typing a name and pressing Return actually renames the folder on
    /// disk — not just that a text field was momentarily visible.
    func testNewFolderEntersRenameAndCommitsTypedName() {
        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 15.0),
            "Wiles main window did not appear within 15 seconds")

        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields["PathBarTextField"]
        XCTAssertTrue(pathField.waitForExistence(timeout: 3.0), "Go to Folder path field did not appear")
        pathField.click()
        pathField.typeText(tempDir.path)
        pathField.typeText("\r")

        // Cmd+Shift+N's menu-bar shortcut isn't reliably synthesizable via `typeKey` under
        // XCUITest, so trigger "New Folder" through the background context menu instead — the
        // same code path a real right-click uses.
        // `app.menuItems.element(boundBy: 0)` matches across the ENTIRE app (menu bar included,
        // ~245 items) not just the just-opened context menu, so filter by the shortcut hint
        // baked into the label — unlike the "New Folder" text itself, it isn't localized.
        let contentArea = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        contentArea.rightClick()
        Thread.sleep(forTimeInterval: 0.5)
        let newFolderMenuItem = app.menuItems.matching(NSPredicate(format: "label CONTAINS 'Shift+Cmd+N'")).firstMatch
        XCTAssertTrue(newFolderMenuItem.waitForExistence(timeout: 3.0), "Background context menu's New Folder item did not appear")
        newFolderMenuItem.click()

        let renameField = app.textFields["InlineRenameField"]
        XCTAssertTrue(
            renameField.waitForExistence(timeout: 3.0),
            "New Folder did not enter inline rename mode")

        // Regression check: previously the field opened then committed/closed itself within a
        // fraction of a second, before the user could type anything.
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(
            renameField.exists,
            "Inline rename field closed itself shortly after opening — New Folder timing regression")

        renameField.click()
        renameField.typeKey("a", modifierFlags: .command)
        renameField.typeText("UITestFolderName")
        renameField.typeText("\r")

        let expectedURL = tempDir.appendingPathComponent("UITestFolderName")
        let renamed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: expectedURL.path) },
            object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [renamed], timeout: 3.0), .completed,
            "Typed name was never committed to disk at \(expectedURL.path)")
    }
}
