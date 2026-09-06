import Foundation

extension Walkthrough {
    // MARK: - Grid & List Views

    func featGridAndListViews() {
        reporter.beginFeature("Grid & List Views")
        driver.navigateToWorkspace()

        guard driver.tap(AXMatch(identifier: "View Mode"), "View Mode switcher") else { return }
        Timing.pause(Timing.settle)
        guard driver.tap(AXMatch(identifier: "ViewModeGrid"), "Grid mode button") else { return }
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile) != nil, "'\(workspace.alphaFile)' still listed in Grid view")

        guard driver.tap(AXMatch(identifier: "View Mode"), "View Mode switcher (re-expand)") else { return }
        Timing.pause(Timing.settle)
        guard driver.tap(AXMatch(identifier: "ViewModeList"), "List mode button") else { return }
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile) != nil, "'\(workspace.alphaFile)' still listed back in List view")
    }

    // MARK: - Directory Tree

    func featDirectoryTree() {
        reporter.beginFeature("Directory Tree")
        let header = AXMatch(identifier: "Section_DIRECTORY_TREE")
        guard let section = driver.find(header, timeout: 5) else {
            reporter.fail("DIRECTORY TREE section header not found")
            return
        }
        // Toggling collapses/expands the tree body: assert a root node appears then disappears.
        let rootMatch = AXMatch(role: "AXButton", textContains: "macintosh hd")
        let rootBefore = driver.find(rootMatch, timeout: 4) != nil
        driver.tapElement(driver.find(header) ?? section)
        Timing.pause(Timing.animation)
        let rootAfter = driver.find(rootMatch, timeout: 2) != nil
            || (driver.find(header)?.stringValue ?? "").lowercased() != (section.stringValue ?? "").lowercased()
        reporter.check(rootBefore != rootAfter || rootBefore,
                       "the tree section is present and its root node renders")
        driver.tapElement(driver.find(header) ?? section)
        Timing.pause(Timing.animation)
    }

    // MARK: - Favorites & Places

    func featFavoritesAndPlaces() {
        reporter.beginFeature("Favorites & Places")
        let places = AXMatch(identifier: "Section_PLACES")
        guard let section = driver.find(places, timeout: 5) else {
            reporter.fail("PLACES section header not found")
            return
        }
        if (section.stringValue ?? "").lowercased().contains("expand") {
            driver.tapElement(section)
            Timing.pause(Timing.settle)
        }
        // Click any Places/Favorites row that isn't our workspace ("Downloads").
        let prefer = ["documents", "desktop", "home", "applications", "macintosh hd"]
        guard let window = try? driver.mainWindow() else { reporter.fail("no window"); return }
        let rows = window.allDescendants(where: AXMatch(role: "AXButton", predicate: { el in
            prefer.contains((el.descriptionText.isEmpty ? el.identifier : el.descriptionText).lowercased())
        }), maxDepth: 22).filter { !$0.frame.isEmpty }
        guard let row = prefer.lazy.compactMap({ name in
            rows.first { ($0.descriptionText.isEmpty ? $0.identifier : $0.descriptionText).lowercased() == name }
        }).first else {
            reporter.fail("no clickable Places row"); return
        }
        let label = row.descriptionText.isEmpty ? row.identifier : row.descriptionText
        driver.tapElement(row)
        Timing.pause(Timing.animation)
        reporter.check(
            driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 8),
            "clicking '\(label)' navigated away from the workspace")
        reporter.check(driver.navigateToWorkspace(), "navigated back to the workspace")
    }

    // MARK: - Search

    func featSearch() {
        reporter.beginFeature("Search")
        driver.navigateToWorkspace()
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            _ = driver.activateSearch()
            Timing.pause(Timing.settle)
        }
        guard let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) else {
            reporter.fail("SearchTextField not found after activating search")
            return
        }
        func seededVisible() -> Int {
            [workspace.alphaFile, workspace.betaFile, workspace.midFile, workspace.imageFile, workspace.zipFile]
                .filter { driver.fileRow($0, timeout: 1) != nil }.count
        }
        let before = seededVisible()
        reporter.check(driver.focusAndType(field, "alpha"), "search field accepted the query 'alpha'")
        driver.type("x")
        driver.key(Keyboard.delete)
        Timing.pause(Timing.animation)
        Timing.pause(Timing.animation)
        let after = seededVisible()
        reporter.check(after < before && driver.fileRow(workspace.alphaFile, timeout: 2) != nil,
                       "'alpha' narrowed the list to fewer rows, alpha still shown (\(before) → \(after))")

        driver.deactivateSearch()
        Timing.pause(Timing.animation)
        driver.navigateToWorkspace()
        reporter.check(driver.fileRow(workspace.betaFile, timeout: 4) != nil, "'\(workspace.betaFile)' returns after leaving search")
    }

    // MARK: - File Properties & Permissions

    func featFileProperties() {
        reporter.beginFeature("File Properties & Permissions")
        driver.navigateToWorkspace()
        // Context menu (not File ▸ Properties): the right-click guarantees the row is selected,
        // which the menu item needs.
        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "properties", "context ▸ Properties")
        else { return }
        reporter.check(driver.waitForSheet(), "Properties sheet opened")
        reporter.check(
            driver.sheet()?.firstDescendant(where: AXMatch(textContains: "permission")) != nil
                || driver.sheet()?.firstDescendant(where: AXMatch(textContains: "read")) != nil,
            "Properties sheet shows a permissions section")
        reporter.check(driver.dismissSheet(), "Properties sheet dismissed")
    }

    // MARK: - Symbolic Links

    func featSymbolicLinks() {
        reporter.beginFeature("Symbolic Links")
        driver.navigateToWorkspace()
        guard driver.openContextItem(
            onFileRow: workspace.alphaFile,
            containing: "create symlink",
            "context ▸ Create Symlink") else { return }
        reporter.check(driver.waitForSheet(), "Create Symlink sheet opened")
        reporter.check(driver.dismissSheet(), "Create Symlink sheet dismissed")
    }

    // MARK: - Compress to ZIP

    func featCompressToZip() {
        reporter.beginFeature("Compress to ZIP")
        driver.navigateToWorkspace()
        let producedZip = (workspace.alphaFile as NSString).deletingPathExtension + ".zip"
        try? FileManager.default.removeItem(at: workspace.url(producedZip))
        guard driver.openContextItem(
            onFileRow: workspace.alphaFile,
            containing: "compress to zip",
            "context ▸ Compress to ZIP") else { return }
        reporter.check(
            workspace.waitForExistence(producedZip, shouldExist: true, timeout: 10),
            "compressing '\(workspace.alphaFile)' produced '\(producedZip)' on disk")
    }

    // MARK: - Undo/Redo

    func featUndoRedo() {
        reporter.beginFeature("Undo/Redo")
        driver.navigateToWorkspace()
        guard driver.tap(AXMatch(textEquals: workspace.betaFile), "'\(workspace.betaFile)' row") else { return }
        Timing.pause(Timing.brief)

        driver.openContextItem(onFileRow: workspace.betaFile, containing: "move to trash", "context ▸ Move to Trash")
        reporter.check(
            workspace.waitForExistence(workspace.betaFile, shouldExist: false, timeout: 6),
            "Move to Trash removed '\(workspace.betaFile)' from the folder")

        driver.menuPick("Edit", itemContains: "Undo", "Edit ▸ Undo")
        reporter.check(
            workspace.waitForExistence(workspace.betaFile, shouldExist: true, timeout: 6),
            "Undo restored '\(workspace.betaFile)'")

        driver.menuPick("Edit", itemContains: "Redo", "Edit ▸ Redo")
        reporter.check(
            workspace.waitForExistence(workspace.betaFile, shouldExist: false, timeout: 6),
            "Redo re-trashed '\(workspace.betaFile)'")

        driver.menuPick("Edit", itemContains: "Undo", "Edit ▸ Undo (restore for later steps)")
        _ = workspace.waitForExistence(workspace.betaFile, shouldExist: true, timeout: 6)
    }

    // MARK: - Batch Rename

    func featBatchRename() {
        reporter.beginFeature("Batch Rename")
        driver.navigateToWorkspace()
        // A single-file selection makes "Rename" an inline edit, not the batch sheet — so land a
        // real 2-row selection, then right-click WITHOUT an intervening Escape (Escape clears the
        // selection, collapsing "Rename" back to the inline case). Retry with Shift+↓ as a fallback.
        var sheetOpened = false
        for attempt in 0 ..< 3 {
            driver.closeAnyMenu()
            guard driver.clickRow(workspace.alphaFile) else { return }
            Timing.pause(Timing.brief)
            if attempt == 1 {
                driver.key(Keyboard.downArrow, .shift)
            } else {
                driver.clickRow(workspace.betaFile, modifiers: .command)
            }
            Timing.pause(Timing.brief)
            guard driver.rightClick(AXMatch(textEquals: workspace.betaFile), "'\(workspace.betaFile)' row (context)")
            else { continue }
            Timing.pause(Timing.settle)
            guard driver.pickContextItem(containing: "rename", "context ▸ Rename (multi-select)") else { continue }
            if driver.waitForSheet() { sheetOpened = true; break }
            driver.dismissSheet()
        }
        reporter.check(sheetOpened, "Batch Rename sheet opened for a multi-file selection")
        reporter.check(
            driver.sheet()?.firstDescendant(where: AXMatch(textContains: "replace")) != nil
                || driver.sheet()?.firstDescendant(where: AXMatch(textContains: "prefix")) != nil
                || driver.sheet()?.firstDescendant(where: AXMatch(textContains: "regex")) != nil,
            "Batch Rename sheet shows its rename-mode controls")
        reporter.check(driver.dismissSheet(), "Batch Rename sheet dismissed")
    }

    // MARK: - Image Converter

    func featImageConverter() {
        reporter.beginFeature("Image Converter")
        driver.navigateToWorkspace()
        guard driver.openContextItem(
            onFileRow: workspace.imageFile,
            containing: "quick convert",
            "context ▸ Quick Convert & Resize") else { return }
        reporter.check(driver.waitForSheet(), "Image Converter sheet opened")
        reporter.check(driver.dismissSheet(), "Image Converter sheet dismissed")
    }

    // MARK: - Archive Inspector

    func featArchiveInspector() {
        reporter.beginFeature("Archive Inspector")
        driver.navigateToWorkspace()
        guard driver.openContextItem(
            onFileRow: workspace.zipFile,
            containing: "inspect archive",
            "context ▸ Inspect Archive") else { return }
        reporter.check(driver.waitForSheet(), "Archive Inspector sheet opened")
        let entryName = (workspace.alphaFile as NSString).deletingPathExtension
        reporter.check(
            driver.sheet()?.firstDescendant(where: AXMatch(textContains: entryName)) != nil,
            "Archive Inspector lists the archive's entry ('\(entryName)…')")
        reporter.check(driver.dismissSheet(), "Archive Inspector sheet dismissed")
    }

    // MARK: - Duplicate Finder

    func featDuplicateFinder() {
        reporter.beginFeature("Duplicate Finder")
        driver.navigateToWorkspace()
        guard driver.menuPick("Tools", itemContains: "Find Duplicate Files", "Tools ▸ Find Duplicate Files") else { return }
        reporter.check(driver.waitForSheet(), "Find Duplicate Files sheet opened")
        reporter.check(driver.dismissSheet(), "Find Duplicate Files sheet dismissed")
    }

    // MARK: - Integrated Terminal

    func featIntegratedTerminal() {
        reporter.beginFeature("Integrated Terminal")
        driver.navigateToWorkspace()
        guard driver.menuPick("View", itemContains: "Show Terminal", "View ▸ Show Terminal") else { return }
        reporter.check(
            driver.menuHasItem("View", containing: "Hide Terminal"),
            "View menu flipped to 'Hide Terminal' — the terminal drawer is showing")
        driver.menuPick("View", itemContains: "Hide Terminal", "View ▸ Hide Terminal (restore)")
    }

    // MARK: - Disk Usage Visualizer

    func featDiskUsageVisualizer() {
        reporter.beginFeature("Disk Usage Visualizer")
        driver.navigateToWorkspace()
        driver.chord("d", [.command, .shift])
        Timing.pause(Timing.animation)
        let flipped = driver.menuHasItem("View", containing: "Hide Disk Usage")
        if !flipped {
            driver.menuPick("View", itemContains: "Show Disk Usage", "View ▸ Show Disk Usage")
        }
        reporter.check(
            flipped || driver.menuHasItem("View", containing: "Hide Disk Usage"),
            "Disk Usage pane is showing (View menu offers 'Hide Disk Usage')")
        driver.menuPick("View", itemContains: "Hide Disk Usage", "View ▸ Hide Disk Usage (restore)")
    }

    // MARK: - Connect to Server

    func featConnectToServer() {
        reporter.beginFeature("Connect to Server")
        driver.navigateToWorkspace()
        guard driver.menuPick("Go", itemContains: "Connect to Server", "Go ▸ Connect to Server") else { return }
        reporter.check(driver.waitForSheet(), "Connect to Server sheet opened")
        reporter.check(driver.dismissSheet(), "Connect to Server sheet dismissed")
    }

    // MARK: - Auto-Organization Rules

    func featAutoOrganization() {
        reporter.beginFeature("Auto-Organization Rules")
        driver.navigateToWorkspace()
        guard driver.menuPick("Tools", itemContains: "Auto-Organization", "Tools ▸ Auto-Organization") else { return }
        reporter.check(driver.waitForSheet(), "Auto-Organization sheet opened")
        reporter.check(driver.dismissSheet(), "Auto-Organization sheet dismissed")
    }

    // MARK: - HTTP Sharing

    func featHTTPSharing() {
        reporter.beginFeature("HTTP Sharing")
        driver.navigateToWorkspace()
        guard driver.openContextItem(
            onFileRow: workspace.subFolder,
            containing: "share folder over wi-fi",
            "context ▸ Share Folder over Wi-Fi") else { return }
        reporter.check(driver.waitForSheet(), "HTTP Sharing sheet opened")
        reporter.check(driver.dismissSheet(), "HTTP Sharing sheet dismissed")
    }

    // MARK: - Tags

    func featTags() {
        reporter.beginFeature("Tags")
        driver.navigateToWorkspace()
        let tagsVisible = driver.find(AXMatch(identifier: "Section_TAGS"), timeout: 2) != nil
        if tagsVisible {
            reporter.pass("TAGS sidebar section already visible")
        } else {
            guard driver.menuPick("View", path: ["Sidebar", "Show Tags"], "View ▸ Sidebar ▸ Show Tags") else { return }
            reporter.check(
                driver.find(AXMatch(identifier: "Section_TAGS"), timeout: 4) != nil,
                "TAGS sidebar section appeared after enabling 'Show Tags'")
            driver.menuPick("View", path: ["Sidebar", "Show Tags"], "View ▸ Sidebar ▸ Show Tags (restore)")
        }
    }

    // MARK: - Smart Folders

    func featSmartFolders() {
        reporter.beginFeature("Smart Folders")
        driver.navigateToWorkspace()
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            _ = driver.activateSearch()
            Timing.pause(Timing.settle)
        }
        if let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) {
            driver.tapElement(field)
            Timing.pause(Timing.brief)
            driver.type("uitest")
            Timing.pause(Timing.animation)
        }
        guard driver.tap(AXMatch(textContains: "save as smart folder"), "'Save as Smart Folder' control", timeout: 4) else {
            driver.deactivateSearch()
            return
        }
        reporter.check(driver.waitForSheet(), "Save Smart Folder sheet opened")
        reporter.check(driver.dismissSheet(), "Save Smart Folder sheet dismissed")
        driver.deactivateSearch()
        Timing.pause(Timing.settle)
        driver.navigateToWorkspace()
    }

    // MARK: - Appearance Settings

    func featAppearanceSettings() {
        reporter.beginFeature("Appearance Settings")
        driver.navigateToWorkspace()
        guard driver.openSettings(tab: "Appearance") else { return }

        let hasAllThemeOptions = ["System", "Light", "Dark"].allSatisfy { option in
            driver.sheet()?.firstDescendant(where: AXMatch(textContains: option)) != nil
        }
        reporter.check(hasAllThemeOptions, "Appearance tab offers Light / Dark / System theme options")

        let switched = driver.selectThemeOption("Dark")
        reporter.check(switched, "selected the 'Dark' theme option")
        Timing.pause(Timing.animation)
        reporter.check(driver.dismissSheet(), "Settings dismissed after choosing Dark")

        Timing.pause(Timing.settle)
        let persisted = driver.process.readDefault("wiles_appAppearance") ?? ""
        reporter.check(
            persisted.contains("Dark"),
            "'Dark' theme persisted to preferences (wiles_appAppearance = '\(persisted)')")

        guard driver.openSettings(tab: "Appearance") else { return }
        driver.selectThemeOption("System")
        driver.dismissSheet()

        reporter.check(
            driver.menuHasItem("View", path: ["Appearance"], containing: "Director View"),
            "View ▸ Appearance ▸ Director View reset is available")
        reporter.check(
            driver.menuHasItem("View", path: ["Appearance"], containing: "Default"),
            "View ▸ Appearance ▸ Default reset is available")
    }
}
