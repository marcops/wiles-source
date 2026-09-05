import XCTest

// MARK: - Wiles full-feature UI walkthrough

//
// ONE test method. Launches Wiles.app once and walks every feature listed in
// wiles-public/FEATURES.md, verifying real behaviour (not just "did not crash"). Each feature
// is its own `feat…()` step so a failure can be bisected by commenting out later steps.
// `continueAfterFailure = true` so one scarce run reports every failing step at once.
//
// ✅ Run: xcodebuild test -scheme Wiles -only-testing:WilesUITests/WilesLaunchUITests \
//      -skip-testing:WilesTests -destination 'platform=macOS,arch=arm64'
// ❌ NOT `swift test` / bare `xcodebuild` — SPM makes a unit bundle, not a ui-testing bundle.
//
// Every filesystem mutation happens inside a per-run temp directory, removed in tearDown.
// A failure at the first `ensureMainWindow()` wait, run duration ≈ the timeout, means macOS's
// relaunch back-off (too many close-spaced runs) — space the runs out; it is not a code bug.
//
// Accessibility identifiers relied on (must stay stable):
//   "Section_FAVORITES" / "Section_PLACES" / "Section_DIRECTORY_TREE" / "Section_TAGS"
//                                                       SidebarSectionHeaderView.swift ~39
//   "Status Bar"                    FooterBarView.swift ~50
//   "PathBarTextField"             PathBarView.swift ~78
//   "SearchTextField"             HeaderBarView.swift ~202
//   "View Mode" / "ViewModeGrid" / "ViewModeList"        HeaderBarView.swift ~409/426
//   "InlineRenameField"          InlineRenameField.swift ~54
//   sidebar rows + file rows carry `.accessibilityLabel(<name>)`      SidebarRowView / FileListView

@MainActor
final class WilesLaunchUITests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    // Standard XCTest lifecycle: set in setUp(), used by the test method — never nil in practice.
    private var app: XCUIApplication!
    private var tempDir: URL!
    // swiftlint:enable implicitly_unwrapped_optional

    private let alphaFile = "alpha-uitest.txt"
    private let betaFile = "beta-uitest.txt"
    private let subFolder = "sub-uitest"
    private let imageFile = "pic-uitest.png"
    private let zipFile = "archive-uitest.zip"

    /// 1×1 transparent PNG.
    private let onePixelPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

    override func setUp() async throws {
        continueAfterFailure = true

        let fm = FileManager.default
        tempDir = fm.temporaryDirectory.appendingPathComponent("WilesUITest-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try "alpha contents".write(to: tempDir.appendingPathComponent(alphaFile), atomically: true, encoding: .utf8)
        try "beta contents".write(to: tempDir.appendingPathComponent(betaFile), atomically: true, encoding: .utf8)
        try fm.createDirectory(at: tempDir.appendingPathComponent(subFolder), withIntermediateDirectories: true)
        if let png = Data(base64Encoded: onePixelPNGBase64) {
            try png.write(to: tempDir.appendingPathComponent(imageFile))
        }
        makeSeedZip(at: tempDir.appendingPathComponent(zipFile))

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch() // already brings the app to the foreground; a second activate() only adds a 60 s stall if the AX bridge is slow
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    // MARK: - Walkthrough (one test, every FEATURES.md feature in order)

    func testWilesFullFeatureWalkthrough() {
        featLaunchShell()
        featFavoritesAndPlaces()
        featDirectoryTree()
        navigateToTempDir()
        featGridAndListViews()
        featSearch()
        featSmartFolders()
        featTags()
        featNewFolder()
        featUndoRedo()
        featFileProperties()
        featSymbolicLinks()
        featCompressToZip()
        featArchiveInspector()
        featImageConverter()
        featBatchRename()
        featHTTPSharing()
        featDuplicateFinder()
        featAutoOrganization()
        featDiskUsageVisualizer()
        featIntegratedTerminal()
        featConnectToServer()
        featAppearanceSettings()
    }

    // MARK: - Feature steps

    private func featLaunchShell() {
        _ = ensureMainWindow()
        let favorites = sidebarSection("Section_FAVORITES")
        XCTAssertTrue(favorites.waitForExistence(timeout: 5.0), "FAVORITES sidebar section not found")
        XCTAssertTrue(favorites.isHittable, "FAVORITES section not hittable")
        XCTAssertTrue(app.staticTexts["Status Bar"].waitForExistence(timeout: 5.0), "Footer 'Status Bar' not found")
    }

    private func featFavoritesAndPlaces() {
        XCTAssertTrue(sidebarSection("Section_PLACES").waitForExistence(timeout: 5.0), "PLACES sidebar section not found")
        let applicationsRow = app.buttons.matching(NSPredicate(format: "label == %@", "Applications")).firstMatch
        XCTAssertTrue(applicationsRow.waitForExistence(timeout: 5.0), "PLACES 'Applications' row not found")
        applicationsRow.click()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ".app")).firstMatch.waitForExistence(timeout: 10.0),
            "Clicking the Applications place did not list any .app bundle")
    }

    private func featDirectoryTree() {
        let tree = sidebarSection("Section_DIRECTORY_TREE")
        let treeRoot = app.buttons.matching(identifier: "Root (/)").firstMatch
        XCTAssertTrue(treeRoot.waitForExistence(timeout: 10.0), "DIRECTORY TREE root row never rendered")
        tree.click()
        XCTAssertTrue(treeRoot.waitForNonExistence(timeout: 5.0), "DIRECTORY TREE still showed its root after collapsing")
        tree.click()
        XCTAssertTrue(treeRoot.waitForExistence(timeout: 10.0), "DIRECTORY TREE root did not return after expanding")
    }

    private func featGridAndListViews() {
        let viewMode = app.buttons["View Mode"]
        XCTAssertTrue(viewMode.waitForExistence(timeout: 3.0), "'View Mode' switcher not found")
        viewMode.click()
        let gridButton = app.buttons.matching(identifier: "ViewModeGrid").firstMatch
        XCTAssertTrue(gridButton.waitForExistence(timeout: 3.0), "Grid view-mode button not found")
        gridButton.click()
        XCTAssertTrue(fileRow(alphaFile).waitForExistence(timeout: 3.0), "'\(alphaFile)' gone after switching to Grid")
        app.buttons["View Mode"].click()
        let listButton = app.buttons.matching(identifier: "ViewModeList").firstMatch
        XCTAssertTrue(listButton.waitForExistence(timeout: 3.0), "List view-mode button not found")
        listButton.click()
        XCTAssertTrue(fileRow(alphaFile).waitForExistence(timeout: 3.0), "'\(alphaFile)' gone after switching back to List")
    }

    private func featSearch() {
        app.typeKey("f", modifierFlags: .command)
        let searchField = app.textFields["SearchTextField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3.0), "Search field did not appear on ⌘F")
        searchField.click()
        searchField.typeText("alpha")
        XCTAssertTrue(fileRow(betaFile).waitForNonExistence(timeout: 4.0), "'\(betaFile)' still shown after searching 'alpha'")
        XCTAssertTrue(fileRow(alphaFile).exists, "'\(alphaFile)' should still match search 'alpha'")
    }

    /// Runs while `featSearch`'s query is still active (the Save control only shows then).
    private func featSmartFolders() {
        let save = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Save as Smart Folder")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 3.0), "'Save as Smart Folder' control not shown while searching")
        save.click()
        XCTAssertTrue(waitForModal(), "Save Smart Folder sheet did not open")
        dismissModal()

        // Close search by toggling ⌘F off (EditMenuCommands `.find` → toggleSearching). Never
        // clear it with ⌘A+Delete: if focus isn't in the field that would trash every file.
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(fileRow(betaFile).waitForExistence(timeout: 3.0), "'\(betaFile)' did not return after leaving search")
    }

    private func featTags() {
        openSettingsTab("Sidebar")
        let toggle = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Show Tags")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 3.0), "'Show Tags' toggle not found in Sidebar settings")
        toggle.click()
        dismissModal()
        XCTAssertTrue(
            sidebarSection("Section_TAGS").waitForExistence(timeout: 3.0),
            "TAGS sidebar section did not appear after enabling 'Show Tags'")
        openSettingsTab("Sidebar")
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Show Tags")).firstMatch.click()
        dismissModal()
    }

    private func featNewFolder() {
        navigateToTempDir()
        contentAreaRightClick()
        let newFolder = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", "Shift+Cmd+N")).firstMatch
        XCTAssertTrue(newFolder.waitForExistence(timeout: 3.0), "Context-menu 'New Folder' item not found")
        newFolder.click()
        let renameField = app.textFields["InlineRenameField"]
        XCTAssertTrue(renameField.waitForExistence(timeout: 3.0), "New Folder did not enter inline rename mode")
        renameField.click()
        renameField.typeKey("a", modifierFlags: .command)
        renameField.typeText("UITestFolder")
        renameField.typeText("\r")
        XCTAssertTrue(waitForPath(newFolderURL, toExist: true), "New folder name not committed to disk at \(newFolderURL.path)")
    }

    private func featUndoRedo() {
        let row = fileRow("UITestFolder")
        XCTAssertTrue(row.waitForExistence(timeout: 3.0), "New folder row not found")
        row.click()
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(waitForPath(newFolderURL, toExist: false), "Folder still on disk after Move to Trash")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(waitForPath(newFolderURL, toExist: true), "⌘Z did not restore the trashed folder")
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertTrue(waitForPath(newFolderURL, toExist: false), "⇧⌘Z did not re-trash the folder")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(waitForPath(newFolderURL, toExist: true), "Second ⌘Z did not restore the folder again")
    }

    private func featFileProperties() {
        fileRow(alphaFile).click()
        app.typeKey("i", modifierFlags: .command)
        XCTAssertTrue(waitForModal(), "Properties sheet did not open on ⌘I")
        dismissModal()
    }

    private func featSymbolicLinks() {
        openContextMenuItem(on: alphaFile, labelContains: "Create Symlink")
        XCTAssertTrue(waitForModal(), "Create Symlink sheet did not open")
        dismissModal()
    }

    private func featCompressToZip() {
        openContextMenuItem(on: alphaFile, labelContains: "Compress to ZIP")
        let producedZip = tempDir.appendingPathComponent("alpha-uitest.zip")
        XCTAssertTrue(
            waitForPath(producedZip, toExist: true, timeout: 15.0),
            "Compress to ZIP did not produce \(producedZip.lastPathComponent)")
    }

    private func featArchiveInspector() {
        openContextMenuItem(on: zipFile, labelContains: "Inspect Archive")
        XCTAssertTrue(waitForModal(), "Inspect Archive sheet did not open")
        dismissModal()
    }

    private func featImageConverter() {
        openContextMenuItem(on: imageFile, labelContains: "Quick Convert")
        XCTAssertTrue(waitForModal(), "Image Converter sheet did not open")
        dismissModal()
    }

    private func featBatchRename() {
        fileRow(alphaFile).click()
        app.typeKey("a", modifierFlags: .command)
        fileRow(betaFile).rightClick()
        let rename = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", "Rename")).firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 3.0), "Context-menu 'Rename' item not found for multi-selection")
        rename.click()
        XCTAssertTrue(waitForModal(), "Batch Rename sheet did not open for a multi-file selection")
        dismissModal()
    }

    private func featHTTPSharing() {
        openContextMenuItem(on: subFolder, labelContains: "Share Folder over Wi-Fi")
        XCTAssertTrue(waitForModal(), "HTTP Sharing sheet did not open")
        dismissModal()
    }

    private func featDuplicateFinder() {
        clickMenuBarItem("Tools", itemContaining: "Find Duplicate Files")
        XCTAssertTrue(waitForModal(), "Find Duplicate Files sheet did not open")
        dismissModal()
    }

    private func featAutoOrganization() {
        clickMenuBarItem("Tools", itemContaining: "Auto-Organization")
        XCTAssertTrue(waitForModal(), "Auto-Organization sheet did not open")
        dismissModal()
    }

    private func featDiskUsageVisualizer() {
        app.typeKey("d", modifierFlags: [.command, .shift])
        XCTAssertTrue(viewMenuItemExists(containing: "Hide Disk Usage"), "View menu did not flip to 'Hide Disk Usage'")
        clickMenuBarItem("View", itemContaining: "Hide Disk Usage")
    }

    private func featIntegratedTerminal() {
        clickMenuBarItem("View", itemContaining: "Show Terminal")
        XCTAssertTrue(viewMenuItemExists(containing: "Hide Terminal"), "View menu did not flip to 'Hide Terminal'")
        clickMenuBarItem("View", itemContaining: "Hide Terminal")
    }

    private func featConnectToServer() {
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(waitForModal(), "Connect to Server sheet did not open on ⌘K")
        dismissModal()
    }

    private func featAppearanceSettings() {
        openSettingsTab("Appearance")
        let dark = themeOption("Dark")
        XCTAssertTrue(dark.waitForExistence(timeout: 3.0), "Theme option 'Dark' not found")
        dark.click()
        dismissModal()
        openSettingsTab("Appearance")
        let darkAfterReopen = themeOption("Dark")
        XCTAssertTrue(darkAfterReopen.waitForExistence(timeout: 3.0), "'Dark' option missing after reopening Settings")
        XCTAssertTrue(darkAfterReopen.isSelected, "Theme did not persist as 'Dark' across Settings reopen")
        themeOption("System").click()
        dismissModal()
    }

    // MARK: - Helpers

    private var newFolderURL: URL {
        tempDir.appendingPathComponent("UITestFolder")
    }

    private func ensureMainWindow() -> XCUIElement {
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 45.0),
            "Wiles main window did not appear within 45 s — relaunch back-off if this follows " +
                "several close-spaced runs; not a code bug")
        return window
    }

    private func sidebarSection(_ identifier: String) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }

    private func fileRow(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func themeOption(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func navigateToTempDir() {
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields["PathBarTextField"]
        XCTAssertTrue(pathField.waitForExistence(timeout: 3.0), "'Go to Folder' path field did not appear on ⌘L")
        pathField.click()
        pathField.typeText(tempDir.path)
        pathField.typeText("\r")
        _ = fileRow(alphaFile).waitForExistence(timeout: 8.0)
    }

    private func contentAreaRightClick() {
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)).rightClick()
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func waitForPath(_ url: URL, toExist shouldExist: Bool, timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate { _, _ in FileManager.default.fileExists(atPath: url.path) == shouldExist }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    private func waitForModal(timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.sheets.firstMatch.exists || app.dialogs.firstMatch.exists {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    private func dismissModal() {
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let deadline = Date().addingTimeInterval(4.0)
        while Date() < deadline {
            if !app.sheets.firstMatch.exists, !app.dialogs.firstMatch.exists {
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("A modal stayed open after pressing Escape")
    }

    private func openContextMenuItem(on fileName: String, labelContains fragment: String) {
        let row = fileRow(fileName)
        XCTAssertTrue(row.waitForExistence(timeout: 3.0), "File row '\(fileName)' not found for its context menu")
        row.rightClick()
        Thread.sleep(forTimeInterval: 0.5)
        let item = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3.0), "Context-menu item containing '\(fragment)' not found on '\(fileName)'")
        item.click()
    }

    private func clickMenuBarItem(_ menuTitle: String, itemContaining fragment: String) {
        app.menuBars.firstMatch.menuBarItems[menuTitle].click()
        let item = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3.0), "Menu item containing '\(fragment)' not found under '\(menuTitle)'")
        item.click()
    }

    private func viewMenuItemExists(containing fragment: String) -> Bool {
        app.menuBars.firstMatch.menuBarItems["View"].click()
        let item = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        let found = item.waitForExistence(timeout: 3.0)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        return found
    }

    private func openSettingsTab(_ tabLabel: String) {
        if !app.sheets.firstMatch.exists {
            app.typeKey(",", modifierFlags: .command)
            _ = waitForModal()
        }
        let tab = app.buttons.matching(NSPredicate(format: "label == %@", tabLabel)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 3.0), "Settings '\(tabLabel)' tab not found")
        tab.click()
    }

    private func makeSeedZip(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tempDir
        process.arguments = ["-j", "-q", url.path, tempDir.appendingPathComponent(alphaFile).path]
        try? process.run()
        process.waitUntilExit()
    }
}
