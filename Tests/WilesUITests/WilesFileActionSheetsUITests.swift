import XCTest

/// UI tests for the file-action sheets: FilePropertiesSheet (Cmd+I "Get Info"),
/// PasswordCompressSheetView, and SymlinkSheetView.
///
/// NOTE on identifiers: none of these three sheets set `.accessibilityIdentifier(...)` on any
/// of their controls (confirmed by grep across Sources/Wiles/Views/Modals — zero matches). There
/// are also zero `.accessibilityIdentifier(` calls anywhere in Sources/Wiles/Views/Content for the
/// file-list rows themselves. Following the precedent already established in
/// WilesCreationSheetsUITests.swift (see its header note), these tests locate elements by their
/// real English copy from Resources/en.lproj/Localizable.strings and by element type/role
/// (sheets, textFields, secureTextFields), and they establish a known, deterministic target file
/// by creating it via the background context menu's "New File..." action rather than assuming
/// anything about pre-existing directory contents.
///
/// NOTE on cleanup: each test creates a real file in whatever folder the app currently has open
/// (via the same right-click -> "New File..." flow used in WilesCreationSheetsUITests), then
/// removes it afterward by selecting it and sending Delete (routes to appState.deleteSelected(),
/// a move-to-trash, so it is reversible from Trash).
final class WilesFileActionSheetsUITests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional - standard XCTest lifecycle property, set in setUp/tearDown
    private nonisolated(unsafe) var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let appURL = URL(fileURLWithPath: "Wiles.app")
        app = FileManager.default.fileExists(atPath: appURL.path) ? XCUIApplication(url: appURL) : XCUIApplication(bundleIdentifier: "com.marco.wiles")
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let run = self.testRun, !run.hasSucceeded {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure_Screenshot_FileActionSheets"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app = nil
    }

    // MARK: - Helpers

    /// Creates a real file with the given name via the background right-click context menu's
    /// "New File..." item, matching the flow already proven to work in
    /// WilesCreationSheetsUITests.testNewFileSheetCreateAndDismiss. The created file ends up
    /// selected in appState (NewFileSheetView sets selectedURLs to it), so callers can act on it
    /// immediately (e.g. Cmd+I) or look it up by name in the file list for a right-click.
    @MainActor private func createKnownFile(named fileName: String) {
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
        textField.typeText(fileName)

        let createButton = sheet.buttons["Create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2.0), "Create button should exist in New File sheet")
        createButton.click()

        XCTAssertFalse(sheet.waitForExistence(timeout: 2.0), "New File sheet should dismiss after creating the file")
    }

    /// Deletes the file at the given row (found by its visible name) by selecting it and sending
    /// Delete, matching the cleanup pattern used elsewhere in this test suite.
    @MainActor private func deleteKnownFile(named fileName: String) {
        let row = app.staticTexts[fileName]
        if row.waitForExistence(timeout: 2.0) {
            row.click()
            app.typeKey(.delete, modifierFlags: [])
        }
    }

    // MARK: - FilePropertiesSheet (Cmd+I "Get Info")

    @MainActor func testFilePropertiesSheetShowsRealContentAndDismisses() throws {
        let fileName = "WilesUITestProperties.txt"
        createKnownFile(named: fileName)

        // NewFileSheetView leaves the created file selected, so Cmd+I ("Properties", disabled
        // when selectedURLs is empty per WilesApp.swift's fileMenuCommands) is immediately usable.
        app.typeKey("i", modifierFlags: .command)

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2.0), "Properties sheet should appear after Cmd+I")

        let nameLabel = sheet.staticTexts[fileName]
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 2.0), "Properties sheet should show the file's real name")

        let sizeLabel = sheet.staticTexts["Size:"]
        XCTAssertTrue(sizeLabel.waitForExistence(timeout: 2.0), "Properties sheet should show a Size row")

        let locationLabel = sheet.staticTexts["Location:"]
        XCTAssertTrue(locationLabel.waitForExistence(timeout: 2.0), "Properties sheet should show a Location row")

        let closeButton = sheet.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2.0), "Properties sheet should have a Close button")
        closeButton.click()

        XCTAssertFalse(sheet.waitForExistence(timeout: 2.0), "Properties sheet should dismiss after clicking Close")

        deleteKnownFile(named: fileName)
    }

    // MARK: - PasswordCompressSheetView (right-click a file -> "Compress with Password...")

    @MainActor func testPasswordCompressSheetShowsAndCancels() throws {
        let fileName = "WilesUITestPasswordCompress.txt"
        createKnownFile(named: fileName)

        let row = app.staticTexts[fileName]
        XCTAssertTrue(row.waitForExistence(timeout: 2.0), "Created file row should exist in the file list before right-clicking it")
        row.rightClick()

        let compressMenuItem = app.menuItems["Compress with Password..."]
        XCTAssertTrue(
            compressMenuItem.waitForExistence(timeout: 2.0),
            "\"Compress with Password...\" context menu item should appear when right-clicking a file"
        )
        compressMenuItem.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2.0), "Password compress sheet should appear after choosing Compress with Password...")

        let passwordField = sheet.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2.0), "Password compress sheet should contain a secure password field")

        let cancelButton = sheet.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2.0), "Password compress sheet should have a Cancel button")
        cancelButton.click()

        XCTAssertFalse(sheet.waitForExistence(timeout: 2.0), "Password compress sheet should dismiss after clicking Cancel")

        deleteKnownFile(named: fileName)
    }

    // MARK: - SymlinkSheetView (right-click a file -> "Create Symlink...")

    @MainActor func testSymlinkSheetShowsPrefilledNameAndCancels() throws {
        let fileName = "WilesUITestSymlinkSource.txt"
        createKnownFile(named: fileName)

        let row = app.staticTexts[fileName]
        XCTAssertTrue(row.waitForExistence(timeout: 2.0), "Created file row should exist in the file list before right-clicking it")
        row.rightClick()

        // SharedViewHelpers.swift's SharedFileItemContextMenu uses the literal, non-localized
        // string "Create Symlink..." for this menu item (unlike most other menu items here, it is
        // not routed through appState.tr(...)).
        let symlinkMenuItem = app.menuItems["Create Symlink..."]
        XCTAssertTrue(
            symlinkMenuItem.waitForExistence(timeout: 2.0),
            "\"Create Symlink...\" context menu item should appear when right-clicking a file"
        )
        symlinkMenuItem.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2.0), "Symlink sheet should appear after choosing Create Symlink...")

        // SymlinkSheetView.onAppear prefills the name field with "<item.name> link".
        let nameField = sheet.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 2.0), "Symlink sheet should contain a name text field")
        let prefilledValue = nameField.value as? String
        XCTAssertEqual(
            prefilledValue,
            "\(fileName) link",
            "Symlink sheet should prefill the name field with '<source name> link'"
        )

        let cancelButton = sheet.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2.0), "Symlink sheet should have a Cancel button")
        cancelButton.click()

        XCTAssertFalse(sheet.waitForExistence(timeout: 2.0), "Symlink sheet should dismiss after clicking Cancel")

        deleteKnownFile(named: fileName)
    }
}
