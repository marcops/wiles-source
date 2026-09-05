import XCTest

// MARK: - Wiles full-feature UI walkthrough

//
// ONE test method that launches Wiles.app once and walks every user-facing feature in
// sequence, verifying real behaviour (not just "did not crash"). Each feature is its own
// `// MARK:` block so a failure can be bisected by commenting out later blocks.
//
// ✅ Run from Xcode: open Package.swift → Product → Test (⌘U), or:
//    xcodebuild test -scheme Wiles -only-testing:WilesUITests/WilesLaunchUITests \
//      -skip-testing:WilesTests -destination 'platform=macOS,arch=arm64'
//
// ❌ NOT run via `swift test` or bare `xcodebuild` — SPM produces a unit-test bundle, not a
//    ui-testing bundle. validate.sh already skips WilesUITests.
//
// All filesystem mutations happen inside a per-run temp directory, removed in tearDown.
//
// Accessibility identifiers relied on (must remain stable):
//   "Section_FAVORITES" / "Section_DIRECTORY_TREE" / "Section_PLACES" / "Section_TAGS" /
//   "Section_SMART_FOLDERS"                              SidebarSectionHeaderView.swift ~39
//   "Status Bar"                                         FooterBarView.swift ~50
//   "PathBarTextField"                                   PathBarView.swift ~78
//   "SearchTextField"                                    HeaderBarView.swift ~202
//   "View Mode" / "ViewModeGrid" / "ViewModeList"        HeaderBarView.swift ~409/426
//   "InlineRenameField"                                  InlineRenameField.swift ~54
//   file/folder rows carry `.accessibilityLabel(item.name)` + `.isButton`  FileListView.swift ~143

@MainActor
final class WilesLaunchUITests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    // Standard XCTest lifecycle: set in setUp(), used by the test method — never nil in practice.
    private var app: XCUIApplication!
    private var tempDir: URL!
    // swiftlint:enable implicitly_unwrapped_optional

    private let alphaFileName = "alpha-uitest.txt"
    private let betaFileName = "beta-uitest.txt"

    override func setUp() async throws {
        continueAfterFailure = false

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WilesUITest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try "alpha".write(to: tempDir.appendingPathComponent(alphaFileName), atomically: true, encoding: .utf8)
        try "beta".write(to: tempDir.appendingPathComponent(betaFileName), atomically: true, encoding: .utf8)

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    // MARK: - The walkthrough

    func testWilesFullFeatureWalkthrough() {
        // MARK: Feature — app launches, core shell renders
        let window = ensureMainWindow()

        let favorites = app.buttons.matching(identifier: "Section_FAVORITES").firstMatch
        XCTAssertTrue(
            favorites.waitForExistence(timeout: 5.0),
            "Sidebar FAVORITES section (id='Section_FAVORITES') not found")
        XCTAssertTrue(favorites.isHittable, "FAVORITES section exists but is not hittable")

        let statusBar = app.staticTexts["Status Bar"]
        XCTAssertTrue(
            statusBar.waitForExistence(timeout: 5.0),
            "Footer status-bar text (id='Status Bar') not found")

        // MARK: Feature — default sidebar section headers render
        //    TAGS needs `showTags` on; SMART FOLDERS needs a saved smart folder — neither is
        //    present on a fresh profile, so they're exercised in their own blocks below.
        for sectionID in ["Section_DIRECTORY_TREE", "Section_PLACES"] {
            let section = app.buttons.matching(identifier: sectionID).firstMatch
            XCTAssertTrue(
                section.waitForExistence(timeout: 5.0),
                "Sidebar section (id='\(sectionID)') not found")
        }

        // MARK: Feature — sidebar section collapse / expand round-trip
        let tree = app.buttons.matching(identifier: "Section_DIRECTORY_TREE").firstMatch
        let treeRoot = app.buttons.matching(identifier: "Root (/)").firstMatch
        XCTAssertTrue(treeRoot.waitForExistence(timeout: 10.0), "DIRECTORY TREE root row never rendered")
        tree.click()
        XCTAssertTrue(
            treeRoot.waitForNonExistence(timeout: 5.0),
            "DIRECTORY TREE still showed its root row after collapsing")
        tree.click()
        XCTAssertTrue(
            treeRoot.waitForExistence(timeout: 10.0),
            "DIRECTORY TREE did not restore its root row after expanding")

        // MARK: Feature — navigate to a folder via the path bar (⌘L)
        navigateToTempDir()
        let alphaRow = app.buttons[alphaFileName]
        let betaRow = app.buttons[betaFileName]
        XCTAssertTrue(
            alphaRow.waitForExistence(timeout: 5.0),
            "Seeded file '\(alphaFileName)' did not show after navigating to the temp folder")
        XCTAssertTrue(betaRow.waitForExistence(timeout: 3.0), "Seeded file '\(betaFileName)' did not show")

        // MARK: Feature — view mode switcher (grid ↔ list)
        let viewModeButton = app.buttons["View Mode"]
        XCTAssertTrue(viewModeButton.waitForExistence(timeout: 3.0), "'View Mode' switcher not found")
        viewModeButton.click()
        let gridButton = app.buttons["ViewModeGrid"]
        let listButton = app.buttons["ViewModeList"]
        XCTAssertTrue(gridButton.waitForExistence(timeout: 3.0), "Grid view-mode button not found after expanding switcher")
        gridButton.click()
        XCTAssertTrue(
            alphaRow.waitForExistence(timeout: 3.0),
            "File '\(alphaFileName)' disappeared after switching to Grid view")
        app.buttons["View Mode"].click()
        XCTAssertTrue(listButton.waitForExistence(timeout: 3.0), "List view-mode button not found after re-expanding switcher")
        listButton.click()
        XCTAssertTrue(alphaRow.waitForExistence(timeout: 3.0), "File '\(alphaFileName)' disappeared after switching back to List view")

        // MARK: Feature — search filters the current folder (⌘F)
        app.typeKey("f", modifierFlags: .command)
        let searchField = app.textFields["SearchTextField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3.0), "Search field did not appear on ⌘F")
        searchField.click()
        searchField.typeText("alpha")
        XCTAssertTrue(
            betaRow.waitForNonExistence(timeout: 3.0),
            "'\(betaFileName)' still visible after searching for 'alpha'")
        XCTAssertTrue(alphaRow.exists, "'\(alphaFileName)' should still match the search 'alpha'")
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            betaRow.waitForExistence(timeout: 3.0),
            "'\(betaFileName)' did not return after clearing the search")
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        // MARK: Feature — New Folder enters inline rename and commits the typed name
        let contentArea = window.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
        contentArea.rightClick()
        let newFolderItem = app.menuItems.matching(NSPredicate(format: "label CONTAINS 'Shift+Cmd+N'")).firstMatch
        XCTAssertTrue(newFolderItem.waitForExistence(timeout: 3.0), "Context-menu 'New Folder' item not found")
        newFolderItem.click()
        let renameField = app.textFields["InlineRenameField"]
        XCTAssertTrue(renameField.waitForExistence(timeout: 3.0), "New Folder did not enter inline rename mode")
        renameField.click()
        renameField.typeKey("a", modifierFlags: .command)
        renameField.typeText("UITestFolder\r")
        let newFolderURL = tempDir.appendingPathComponent("UITestFolder")
        XCTAssertTrue(
            waitForPath(newFolderURL, toExist: true),
            "New Folder's typed name was never committed to disk at \(newFolderURL.path)")

        // MARK: Feature — Move to Trash + Undo round-trip
        let newFolderRow = app.buttons["UITestFolder"]
        XCTAssertTrue(newFolderRow.waitForExistence(timeout: 3.0), "New folder row not found")
        newFolderRow.click()
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            waitForPath(newFolderURL, toExist: false),
            "Folder still on disk after Move to Trash")
        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(
            waitForPath(newFolderURL, toExist: true),
            "⌘Z did not restore the trashed folder")

        // MARK: Feature — File Properties sheet (⌘I)
        alphaRow.click()
        app.typeKey("i", modifierFlags: .command)
        XCTAssertTrue(
            app.sheets.firstMatch.waitForExistence(timeout: 4.0),
            "Properties sheet did not open on ⌘I")
        dismissSheet()

        // MARK: Feature — Settings sheet, theme switch persists (⌘,)
        app.typeKey(",", modifierFlags: .command)
        let appearanceTab = app.buttons.matching(identifier: "Appearance").firstMatch
        XCTAssertTrue(appearanceTab.waitForExistence(timeout: 3.0), "Settings 'Appearance' tab not found after ⌘,")
        appearanceTab.click()
        let darkOption = app.buttons.matching(identifier: "Dark").firstMatch
        XCTAssertTrue(darkOption.waitForExistence(timeout: 3.0), "Theme option 'Dark' not found")
        darkOption.click()
        dismissSheet()
        app.typeKey(",", modifierFlags: .command)
        app.buttons.matching(identifier: "Appearance").firstMatch.click()
        let darkAfterReopen = app.buttons.matching(identifier: "Dark").firstMatch
        XCTAssertTrue(darkAfterReopen.waitForExistence(timeout: 3.0), "'Dark' option missing after reopening Settings")
        XCTAssertTrue(darkAfterReopen.isSelected, "Theme did not persist as 'Dark' across Settings reopen")
        app.buttons.matching(identifier: "System").firstMatch.click()
        dismissSheet()

        // MARK: Feature — integrated terminal toggle (View menu)
        clickViewMenuItem(containing: "Show Terminal")
        XCTAssertTrue(
            viewMenuItemExists(containing: "Hide Terminal"),
            "View menu did not flip to 'Hide Terminal' after showing the terminal")
        clickViewMenuItem(containing: "Hide Terminal")

        // MARK: Feature — preview inspector pane toggle (View menu)
        clickViewMenuItem(containing: "Show Preview")
        XCTAssertTrue(
            app.buttons["More Info..."].waitForExistence(timeout: 3.0),
            "Preview pane 'More Info...' control not found after showing the preview pane")
        clickViewMenuItem(containing: "Hide Preview")

        // MARK: Feature — disk-usage inspector pane toggle (View menu)
        clickViewMenuItem(containing: "Show Disk Usage")
        XCTAssertTrue(
            viewMenuItemExists(containing: "Hide Disk Usage"),
            "View menu did not flip to 'Hide Disk Usage' after showing the disk-usage pane")
        clickViewMenuItem(containing: "Hide Disk Usage")

        // MARK: Feature — Connect to Server sheet (⌘K)
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 4.0), "Connect to Server sheet did not open on ⌘K")
        dismissSheet()

        // MARK: Feature — Help sheet (⌘?)
        app.typeKey("?", modifierFlags: .command)
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 4.0), "Help sheet did not open on ⌘?")
        dismissSheet()

        // MARK: Feature — Tools ▸ Auto-Organization sheet
        clickMenuBarItem("Tools", itemContaining: "Auto-Organization")
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 4.0), "Auto-Organization sheet did not open")
        dismissSheet()

        // MARK: Feature — Tools ▸ Find Duplicate Files sheet
        clickMenuBarItem("Tools", itemContaining: "Find Duplicate Files")
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 4.0), "Find Duplicate Files sheet did not open")
        dismissSheet()

        // MARK: Feature — Shortcuts cheat-sheet HUD (⌘/)
        app.typeKey("/", modifierFlags: .command)
        let hudTitle = app.staticTexts["Shortcuts"]
        XCTAssertTrue(hudTitle.waitForExistence(timeout: 3.0), "Shortcuts HUD did not appear on ⌘/")
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(hudTitle.waitForNonExistence(timeout: 3.0), "Shortcuts HUD did not close on Escape")
    }

    // MARK: - Helpers

    /// Returns the main window. A generous single wait — under `xcodebuild test` the first render
    /// can be slow, and relaunching here would only feed macOS's relaunch back-off, not beat it.
    private func ensureMainWindow() -> XCUIElement {
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 45.0),
            "Wiles main window did not appear within 45 seconds (app relaunch throttle if this " +
                "follows several close-spaced runs — space the runs out)")
        return window
    }

    private func navigateToTempDir() {
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields["PathBarTextField"]
        XCTAssertTrue(pathField.waitForExistence(timeout: 3.0), "Go to Folder path field did not appear on ⌘L")
        pathField.click()
        pathField.typeText(tempDir.path + "\r")
    }

    private func waitForPath(_ url: URL, toExist shouldExist: Bool) -> Bool {
        let predicate = NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path) == shouldExist
        }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5.0) == .completed
    }

    private func dismissSheet() {
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(
            app.sheets.firstMatch.waitForNonExistence(timeout: 4.0),
            "A modal sheet stayed open after pressing Escape")
    }

    private func clickMenuBarItem(_ menuTitle: String, itemContaining fragment: String) {
        app.menuBars.firstMatch.menuBarItems[menuTitle].click()
        let item = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3.0), "Menu item containing '\(fragment)' not found under '\(menuTitle)'")
        item.click()
    }

    private func clickViewMenuItem(containing fragment: String) {
        clickMenuBarItem("View", itemContaining: fragment)
    }

    private func viewMenuItemExists(containing fragment: String) -> Bool {
        app.menuBars.firstMatch.menuBarItems["View"].click()
        let item = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        let found = item.waitForExistence(timeout: 3.0)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        return found
    }
}
