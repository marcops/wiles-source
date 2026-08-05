import XCTest

/// UI tests for the creation/rename single-input sheets (NewFileSheetView, NewFolderSheet,
/// RenameSheetView), all backed by the shared SingleInputSheetView.
///
/// NOTE on identifiers: none of NewFileSheetView / NewFolderSheet / RenameSheetView /
/// SingleInputSheetView set `.accessibilityIdentifier(...)` on their text field or buttons
/// (confirmed by grep across Sources/Wiles/Views). These tests therefore locate elements by
/// their real English copy from Resources/en.lproj/Localizable.strings ("Create New Folder",
/// "New File", "Rename", "Create", "Cancel") and by element type (sheets/textFields), matching
/// the reference test's `waitForExistence` discipline.
///
/// NOTE on cleanup: each test creates (or renames) a real item in whatever folder the app
/// currently has open. After asserting the sheet dismissed, the test selects the created/renamed
/// item and sends the Delete key, which routes through `onDeleteCommand` -> `appState.deleteSelected()`
/// (a move-to-trash, not a permanent delete) so the side effect is reversible from Trash. Rename's
/// cleanup only removes the renamed item; it does not attempt to restore the original name first,
/// since UI-level restore is itself untested territory here.
final class WilesCreationSheetsUITests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional - standard XCTest lifecycle property, set in setUp/tearDown
    private nonisolated(unsafe) var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let run = self.testRun, !run.hasSucceeded {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure_Screenshot_CreationSheets"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app = nil
    }

    // MARK: - New Folder (Cmd+Shift+N, always available regardless of selection)

    @MainActor
    func testNewFolderSheetCreateAndDismiss() throws {
        app.typeKey("n", modifierFlags: [.command, .shift])

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2.0), "New Folder sheet should appear after Cmd+Shift+N")

        let textField = sheet.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 2.0), "New Folder sheet should contain a text field")

        textField.click()
        // Clear the prefilled "New Folder" default value before typing our own name.
        if let currentValue = textField.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            textField.typeText(deleteString)
        }
        let folderName = "WilesUITestFolder"
        textField.typeText(folderName)

        let createButton = sheet.buttons["Create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2.0), "Create button should exist in New Folder sheet")
        createButton.click()

        XCTAssertFalse(sheet.waitForExistence(timeout: 2.0), "New Folder sheet should dismiss after creating the folder")

        // Cleanup: the newly created folder is not auto-selected by NewFolderSheet, so select it
        // by name in the file list before deleting.
        let createdRow = app.staticTexts[folderName]
        if createdRow.waitForExistence(timeout: 2.0) {
            createdRow.click()
            app.typeKey(.delete, modifierFlags: [])
        }
    }

    // MARK: - New File (right-click background context menu -> "New File...")

    @MainActor
    func testNewFileSheetCreateAndDismiss() throws {
        let contentArea = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.7))
        contentArea.rightClick()

        let newFileMenuItem = app.menuItems["New File..."]
        XCTAssertTrue(newFileMenuItem.waitForExistence(timeout: 2.0), "\"New File...\" context menu item should appear on right click")
        newFileMenuItem.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2.0), "New File sheet should appear after choosing New File...")

        let textField = sheet.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 2.0), "New File sheet should contain a text field")

        textField.click()
        if let currentValue = textField.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            textField.typeText(deleteString)
        }
        let fileName = "WilesUITestFile.txt"
        textField.typeText(fileName)

        let createButton = sheet.buttons["Create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2.0), "Create button should exist in New File sheet")
        createButton.click()

        XCTAssertFalse(sheet.waitForExistence(timeout: 2.0), "New File sheet should dismiss after creating the file")

        // Cleanup: NewFileSheetView sets appState.selectedURLs to the created file, so Delete
        // should act on it directly without needing to re-select it in the list.
        app.typeKey(.delete, modifierFlags: [])
    }

    // MARK: - Rename (select the file just created, press F2 in default GNOME navigation mode)

    /// Creates a file to rename, reusing the New File flow so we have a known, selected item.
    /// Split out of testRenameSheetSubmitAndDismiss to keep that test under the function body
    /// length limit; behavior is unchanged.
    @MainActor
    private func createFileForRenameTest(named originalName: String) throws {
        let contentArea = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.7))
        contentArea.rightClick()
        let newFileMenuItem = app.menuItems["New File..."]
        XCTAssertTrue(newFileMenuItem.waitForExistence(timeout: 2.0), "\"New File...\" context menu item should appear on right click")
        newFileMenuItem.click()

        let creationSheet = app.sheets.firstMatch
        XCTAssertTrue(creationSheet.waitForExistence(timeout: 2.0), "New File sheet should appear before rename setup")
        let creationTextField = creationSheet.textFields.firstMatch
        XCTAssertTrue(creationTextField.waitForExistence(timeout: 2.0), "New File sheet should contain a text field")
        creationTextField.click()
        if let currentValue = creationTextField.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            creationTextField.typeText(deleteString)
        }
        creationTextField.typeText(originalName)
        let creationCreateButton = creationSheet.buttons["Create"]
        XCTAssertTrue(creationCreateButton.waitForExistence(timeout: 2.0), "Create button should exist in New File sheet")
        creationCreateButton.click()
        XCTAssertFalse(creationSheet.waitForExistence(timeout: 2.0), "New File sheet should dismiss before renaming")
    }

    @MainActor
    func testRenameSheetSubmitAndDismiss() throws {
        let originalName = "WilesUITestRenameMe.txt"
        try createFileForRenameTest(named: originalName)

        // The created file is auto-selected by NewFileSheetView. Default navigation mode is
        // GNOME, where F2 (not Return) triggers rename for the current selection.
        app.typeKey(.F2, modifierFlags: [])

        let renameSheet = app.sheets.firstMatch
        XCTAssertTrue(renameSheet.waitForExistence(timeout: 2.0), "Rename sheet should appear after pressing F2 with a file selected")

        let renameTextField = renameSheet.textFields.firstMatch
        XCTAssertTrue(renameTextField.waitForExistence(timeout: 2.0), "Rename sheet should contain a text field")

        renameTextField.click()
        if let currentValue = renameTextField.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            renameTextField.typeText(deleteString)
        }
        let renamedName = "WilesUITestRenamed.txt"
        renameTextField.typeText(renamedName)

        let renameButton = renameSheet.buttons["Rename"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 2.0), "Rename button should exist in Rename sheet")
        renameButton.click()

        XCTAssertFalse(renameSheet.waitForExistence(timeout: 2.0), "Rename sheet should dismiss after renaming")

        // Cleanup: select the renamed item by its new name and delete it (move to Trash).
        let renamedRow = app.staticTexts[renamedName]
        if renamedRow.waitForExistence(timeout: 2.0) {
            renamedRow.click()
            app.typeKey(.delete, modifierFlags: [])
        }
    }
}
