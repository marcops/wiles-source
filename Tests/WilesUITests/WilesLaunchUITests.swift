import XCTest

// MARK: - Wiles full-feature UI walkthrough

//
// ONE test method. Launches Wiles.app once and walks every feature listed in
// wiles-public/FEATURES.md, verifying real behaviour (not just "did not crash"). Each feature
// is its own `feat…()` step; every UI interaction goes through `tap`/`rightClick`, which record
// an `XCTFail` and return instead of hard-aborting when an element is missing — so one run with
// `continueAfterFailure = true` reports every failing step at once.
//
// ✅ Run: xcodebuild test -scheme Wiles -only-testing:WilesUITests/WilesLaunchUITests \
//      -skip-testing:WilesTests -destination 'platform=macOS,arch=arm64'
// ❌ NOT `swift test` / bare `xcodebuild` — SPM makes a unit bundle, not a ui-testing bundle.
//
// Every filesystem mutation happens inside a per-run temp directory, removed in tearDown.
// A failure at the first `ensureMainWindow()` wait, run duration ≈ the timeout, means macOS's
// app relaunch back-off (too many close-spaced launches) — space runs out; not a code bug.
//
// Accessibility identifiers relied on (must stay stable):
//   "Section_FAVORITES" / "Section_PLACES" / "Section_DIRECTORY_TREE" / "Section_TAGS"
//                                                       SidebarSectionHeaderView.swift ~39
//   sidebar rows carry `.accessibilityIdentifier(item.name)`          SidebarRowView.swift ~54
//   "Status Bar"                    FooterBarView.swift ~50
//   "PathBarTextField"             PathBarView.swift ~78
//   "SearchTextField"             HeaderBarView.swift ~202
//   "View Mode" / "ViewModeGrid" / "ViewModeList"        HeaderBarView.swift ~409/426
//   "InlineRenameField"          InlineRenameField.swift ~54
//   file rows carry `.accessibilityLabel(item.name)` + `.isButton`    FileListView.swift ~143

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

        clearStaleWindowState()

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch() // launch() already foregrounds; a second activate() only stalls when the AX bridge is slow
    }

    /// A saved off-screen `NSWindow Frame` autosave (or a stale restored path) makes the app
    /// launch as a running process with **no composited window** — every UI query then fails
    /// against nothing. Wipe just those keys before each launch so the run starts deterministic;
    /// favorites / sidebar-visibility prefs are left intact so those sections still render.
    private func clearStaleWindowState() {
        var keys = ["wiles_lastOpenedFolder"]
        for index in 1 ... 5 {
            keys.append("NSWindow Frame main-AppWindow-\(index)")
        }
        for key in keys {
            let defaults = Process()
            defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            defaults.arguments = ["delete", "com.marco.wiles.uitest", key]
            defaults.standardOutput = FileHandle.nullDevice
            defaults.standardError = FileHandle.nullDevice
            try? defaults.run()
            defaults.waitUntilExit()
        }
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
        guard exists(favorites, "FAVORITES sidebar section") else { return }
        XCTAssertTrue(favorites.isHittable, "FAVORITES section not hittable")
        XCTAssertTrue(app.staticTexts["Status Bar"].waitForExistence(timeout: 5.0), "Footer 'Status Bar' not found")
    }

    private func featFavoritesAndPlaces() {
        let places = sidebarSection("Section_PLACES")
        guard exists(places, "PLACES sidebar section") else { return }
        let applications = sidebarRow("Applications")
        if !applications.waitForExistence(timeout: 2.0) {
            tap(places, "PLACES section header (to expand)") // rows are hidden while the section is collapsed
        }
        guard tap(applications, "PLACES 'Applications' row") else { return }
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ".app")).firstMatch.waitForExistence(timeout: 10.0),
            "Clicking the Applications place did not list any .app bundle")
    }

    private func featDirectoryTree() {
        let tree = sidebarSection("Section_DIRECTORY_TREE")
        guard exists(tree, "DIRECTORY TREE section header") else { return }
        let treeRoot = app.buttons.matching(identifier: "Root (/)").firstMatch
        if !treeRoot.waitForExistence(timeout: 3.0) {
            tap(tree, "DIRECTORY TREE section header (to expand)") // the section is collapsed on a fresh profile
        }
        guard exists(treeRoot, "DIRECTORY TREE root row", timeout: 10.0) else { return }
        guard tap(tree, "DIRECTORY TREE section header") else { return }
        XCTAssertTrue(treeRoot.waitForNonExistence(timeout: 5.0), "DIRECTORY TREE still showed its root after collapsing")
        guard tap(tree, "DIRECTORY TREE section header") else { return }
        XCTAssertTrue(treeRoot.waitForExistence(timeout: 10.0), "DIRECTORY TREE root did not return after expanding")
    }

    private func featGridAndListViews() {
        guard tap(app.buttons["View Mode"], "'View Mode' switcher") else { return }
        guard tap(app.buttons.matching(identifier: "ViewModeGrid").firstMatch, "Grid view-mode button") else { return }
        XCTAssertTrue(fileRow(alphaFile).waitForExistence(timeout: 3.0), "'\(alphaFile)' gone after switching to Grid")
        guard tap(app.buttons["View Mode"], "'View Mode' switcher (re-expand)") else { return }
        guard tap(app.buttons.matching(identifier: "ViewModeList").firstMatch, "List view-mode button") else { return }
        XCTAssertTrue(fileRow(alphaFile).waitForExistence(timeout: 3.0), "'\(alphaFile)' gone after switching back to List")
    }

    private func featSearch() {
        app.typeKey("f", modifierFlags: .command)
        let searchField = app.textFields["SearchTextField"]
        guard tap(searchField, "search field (⌘F)") else { return }
        searchField.typeText("alpha")
        XCTAssertTrue(fileRow(betaFile).waitForNonExistence(timeout: 4.0), "'\(betaFile)' still shown after searching 'alpha'")
        XCTAssertTrue(fileRow(alphaFile).exists, "'\(alphaFile)' should still match search 'alpha'")
    }

    /// Runs while `featSearch`'s query is still active (the Save control only shows then).
    private func featSmartFolders() {
        let save = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Save as Smart Folder")).firstMatch
        guard tap(save, "'Save as Smart Folder' control") else {
            app.typeKey("f", modifierFlags: .command) // still leave search
            return
        }
        XCTAssertTrue(waitForModal(), "Save Smart Folder sheet did not open")
        dismissModal()
        // Leave search by toggling ⌘F off (EditMenuCommands `.find` → toggleSearching). Never
        // clear it with ⌘A+Delete: if focus isn't in the field that would trash every file.
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(fileRow(betaFile).waitForExistence(timeout: 3.0), "'\(betaFile)' did not return after leaving search")
    }

    private func featTags() {
        guard openSettingsTab("Sidebar") else { return }
        let toggle = firstByLabel("Show Tags")
        guard tap(toggle, "'Show Tags' toggle") else { dismissModal()
            return
        }
        dismissModal()
        XCTAssertTrue(
            sidebarSection("Section_TAGS").waitForExistence(timeout: 3.0),
            "TAGS sidebar section did not appear after enabling 'Show Tags'")
        guard openSettingsTab("Sidebar") else { return }
        tap(firstByLabel("Show Tags"), "'Show Tags' toggle (restore)")
        dismissModal()
    }

    private func featNewFolder() {
        navigateToTempDir()
        contentAreaRightClick()
        let newFolder = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", "Shift+Cmd+N")).firstMatch
        guard tap(newFolder, "context-menu 'New Folder' item") else { return }
        let renameField = app.textFields["InlineRenameField"]
        guard tap(renameField, "inline rename field") else { return }
        renameField.typeKey("a", modifierFlags: .command)
        renameField.typeText("UITestFolder")
        renameField.typeText("\r")
        XCTAssertTrue(waitForPath(newFolderURL, toExist: true), "New folder name not committed to disk at \(newFolderURL.path)")
    }

    private func featUndoRedo() {
        guard tap(fileRow("UITestFolder"), "new folder row") else { return }
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
        guard tap(fileRow(alphaFile), "'\(alphaFile)' row") else { return }
        app.typeKey("i", modifierFlags: .command)
        XCTAssertTrue(waitForModal(), "Properties sheet did not open on ⌘I")
        dismissModal()
    }

    private func featSymbolicLinks() {
        guard openContextMenuItem(on: alphaFile, labelContains: "Create Symlink") else { return }
        XCTAssertTrue(waitForModal(), "Create Symlink sheet did not open")
        dismissModal()
    }

    private func featCompressToZip() {
        guard openContextMenuItem(on: alphaFile, labelContains: "Compress to ZIP") else { return }
        let producedZip = tempDir.appendingPathComponent("alpha-uitest.zip")
        XCTAssertTrue(
            waitForPath(producedZip, toExist: true, timeout: 15.0),
            "Compress to ZIP did not produce \(producedZip.lastPathComponent)")
    }

    private func featArchiveInspector() {
        guard openContextMenuItem(on: zipFile, labelContains: "Inspect Archive") else { return }
        XCTAssertTrue(waitForModal(), "Inspect Archive sheet did not open")
        dismissModal()
    }

    private func featImageConverter() {
        guard openContextMenuItem(on: imageFile, labelContains: "Quick Convert") else { return }
        XCTAssertTrue(waitForModal(), "Image Converter sheet did not open")
        dismissModal()
    }

    private func featBatchRename() {
        guard tap(fileRow(alphaFile), "'\(alphaFile)' row") else { return }
        app.typeKey("a", modifierFlags: .command)
        guard rightClick(fileRow(betaFile), "'\(betaFile)' row") else { return }
        Thread.sleep(forTimeInterval: 0.5)
        let rename = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", "Rename")).firstMatch
        guard tap(rename, "context-menu 'Rename' item (multi-selection)") else { return }
        XCTAssertTrue(waitForModal(), "Batch Rename sheet did not open for a multi-file selection")
        dismissModal()
    }

    private func featHTTPSharing() {
        guard openContextMenuItem(on: subFolder, labelContains: "Share Folder over Wi-Fi") else { return }
        XCTAssertTrue(waitForModal(), "HTTP Sharing sheet did not open")
        dismissModal()
    }

    private func featDuplicateFinder() {
        guard clickMenuBarItem("Tools", itemContaining: "Find Duplicate Files") else { return }
        XCTAssertTrue(waitForModal(), "Find Duplicate Files sheet did not open")
        dismissModal()
    }

    private func featAutoOrganization() {
        guard clickMenuBarItem("Tools", itemContaining: "Auto-Organization") else { return }
        XCTAssertTrue(waitForModal(), "Auto-Organization sheet did not open")
        dismissModal()
    }

    private func featDiskUsageVisualizer() {
        app.typeKey("d", modifierFlags: [.command, .shift])
        XCTAssertTrue(viewMenuItemExists(containing: "Hide Disk Usage"), "View menu did not flip to 'Hide Disk Usage'")
        clickMenuBarItem("View", itemContaining: "Hide Disk Usage")
    }

    private func featIntegratedTerminal() {
        guard clickMenuBarItem("View", itemContaining: "Show Terminal") else { return }
        XCTAssertTrue(viewMenuItemExists(containing: "Hide Terminal"), "View menu did not flip to 'Hide Terminal'")
        clickMenuBarItem("View", itemContaining: "Hide Terminal")
    }

    private func featConnectToServer() {
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(waitForModal(), "Connect to Server sheet did not open on ⌘K")
        dismissModal()
    }

    private func featAppearanceSettings() {
        guard openSettingsTab("Appearance") else { return }
        guard tap(themeOption("Dark"), "theme option 'Dark'") else { dismissModal()
            return
        }
        dismissModal()
        guard openSettingsTab("Appearance") else { return }
        let darkAfterReopen = themeOption("Dark")
        if exists(darkAfterReopen, "'Dark' option after reopening Settings", timeout: 3.0) {
            XCTAssertTrue(darkAfterReopen.isSelected, "Theme did not persist as 'Dark' across Settings reopen")
        }
        tap(themeOption("System"), "theme option 'System' (restore)")
        dismissModal()
    }

    // MARK: - Interaction helpers (record failure + return, never hard-abort)

    @discardableResult
    private func exists(_ element: XCUIElement, _ description: String, timeout: TimeInterval = 5.0) -> Bool {
        if element.waitForExistence(timeout: timeout) {
            return true
        }
        XCTFail("\(description) not found")
        return false
    }

    @discardableResult
    private func tap(_ element: XCUIElement, _ description: String, timeout: TimeInterval = 5.0) -> Bool {
        guard exists(element, description, timeout: timeout) else { return false }
        element.click()
        return true
    }

    @discardableResult
    private func rightClick(_ element: XCUIElement, _ description: String, timeout: TimeInterval = 5.0) -> Bool {
        guard exists(element, description, timeout: timeout) else { return false }
        element.rightClick()
        return true
    }

    // MARK: - Element helpers

    private var newFolderURL: URL {
        tempDir.appendingPathComponent("UITestFolder")
    }

    private func ensureMainWindow() -> XCUIElement {
        let window = app.windows.firstMatch
        // Wiles either shows its window near-instantly or not at all: a 10 s ceiling fails fast
        // instead of burning ~45 s per run when the launch silently produced no window.
        XCTAssertTrue(
            window.waitForExistence(timeout: 10.0),
            "Wiles main window did not appear within 10 s of launch")
        return window
    }

    private func sidebarSection(_ identifier: String) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }

    private func sidebarRow(_ name: String) -> XCUIElement {
        app.buttons.matching(identifier: name).firstMatch
    }

    private func fileRow(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func themeOption(_ label: String) -> XCUIElement {
        firstByLabel(label)
    }

    private func firstByLabel(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func navigateToTempDir() {
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields["PathBarTextField"]
        guard tap(pathField, "'Go to Folder' path field (⌘L)") else { return }
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

    @discardableResult
    private func openContextMenuItem(on fileName: String, labelContains fragment: String) -> Bool {
        guard rightClick(fileRow(fileName), "file row '\(fileName)' (for its context menu)") else { return false }
        Thread.sleep(forTimeInterval: 0.5)
        let item = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        return tap(item, "context-menu item containing '\(fragment)' on '\(fileName)'")
    }

    @discardableResult
    private func clickMenuBarItem(_ menuTitle: String, itemContaining fragment: String) -> Bool {
        guard tap(app.menuBars.firstMatch.menuBarItems[menuTitle], "menu-bar '\(menuTitle)'") else { return false }
        let item = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        return tap(item, "menu item containing '\(fragment)' under '\(menuTitle)'")
    }

    private func viewMenuItemExists(containing fragment: String) -> Bool {
        guard tap(app.menuBars.firstMatch.menuBarItems["View"], "menu-bar 'View'") else { return false }
        let item = app.menuItems.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        let found = item.waitForExistence(timeout: 3.0)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        return found
    }

    @discardableResult
    private func openSettingsTab(_ tabLabel: String) -> Bool {
        if !app.sheets.firstMatch.exists {
            app.typeKey(",", modifierFlags: .command)
            _ = waitForModal()
        }
        return tap(firstByLabel(tabLabel), "Settings '\(tabLabel)' tab")
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
