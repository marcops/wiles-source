import Foundation

extension PlanWalkthrough {
    /// Top-most seeded file/folder row currently in the content list (by on-screen Y).
    func firstContentRowLabel() -> String {
        let names = [
            workspace.alphaFile, workspace.betaFile, workspace.subFolder,
            workspace.imageFile, workspace.zipFile, workspace.pdfOne, workspace.pdfTwo,
        ]
        guard let window = try? driver.mainWindow() else { return "" }
        let rows = window.allDescendants(where: AXMatch(role: "AXButton", predicate: { element in
            names.contains(element.descriptionText) || names.contains(element.title)
        }), maxDepth: 18)
        return rows
            .filter { !$0.frame.isEmpty }
            .min { $0.frame.minY < $1.frame.minY }
            .map { $0.descriptionText.isEmpty ? $0.title : $0.descriptionText } ?? ""
    }

    // MARK: - Windows

    func featNewAndCloseWindow() {
        reporter.beginFeature("New / Close window (⌘N, ⌘W)")
        let before = driver.standardWindowCount
        driver.menuPick("File", itemContains: "New Window", "File ▸ New Window")
        Timing.pause(Timing.animation)
        let opened = driver.standardWindowCount
        reporter.check(opened == before + 1, "⌘N opened a second window (\(before) → \(opened))")

        driver.chord("w", .command)
        Timing.pause(Timing.animation)
        driver.resetWindowCache()
        let closed = driver.standardWindowCount
        reporter.check(closed == before, "⌘W closed it (\(opened) → \(closed))")
    }

    // MARK: - Sidebar

    func featSidebarSectionHeaders() {
        reporter.beginFeature("Sidebar section headers")
        for identifier in ["Section_FAVORITES", "Section_PLACES", "Section_DIRECTORY_TREE"] {
            let header = driver.find(AXMatch(identifier: identifier), timeout: 3)
            reporter.check(header != nil && !(header?.frame.isEmpty ?? true), "\(identifier) present and on screen")
        }
    }

    func featSectionCollapsePersists() {
        // Persistence is verified against durable storage (the toggle writes `wiles_isFavoritesExpanded`
        // which `SidebarPreferences.load` restores on next launch). An in-run relaunch is avoided —
        // it drives macOS's app relaunch back-off and is flaky.
        reporter.beginFeature("Section collapse writes through to preferences")
        guard let favorites = driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 3) else {
            reporter.fail("Section_FAVORITES not found")
            return
        }
        if (favorites.stringValue ?? "").lowercased().contains("collapse") {
            driver.tapElement(favorites)
            Timing.pause(Timing.animation)
        }
        let collapsed = (driver.find(AXMatch(identifier: "Section_FAVORITES"))?.stringValue ?? "").lowercased()
        reporter.check(collapsed.contains("expand"), "FAVORITES collapsed in the UI (value '\(collapsed)')")
        Timing.pause(Timing.settle)
        let persistedCollapsed = driver.process.readDefault("wiles_isFavoritesExpanded") ?? ""
        reporter.check(
            persistedCollapsed == "0",
            "collapse persisted (wiles_isFavoritesExpanded = '\(persistedCollapsed)')")

        driver.tapElement(driver.find(AXMatch(identifier: "Section_FAVORITES")) ?? favorites)
        Timing.pause(Timing.animation)
        let persistedExpanded = driver.process.readDefault("wiles_isFavoritesExpanded") ?? ""
        reporter.check(
            persistedExpanded == "1",
            "re-expand persisted too (wiles_isFavoritesExpanded = '\(persistedExpanded)')")
        driver.navigateToWorkspace()
    }

    func featHideShowSection() {
        reporter.beginFeature("Hide a section via context menu, re-show from View menu")
        guard let places = driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 3) else {
            reporter.fail("Section_PLACES not found")
            return
        }
        driver.rightClick(AXMatch(identifier: "Section_PLACES"), "PLACES header (context menu)")
        Timing.pause(Timing.settle)
        _ = places
        guard driver.pickContextItem(containing: "hide", "context ▸ Hide <section>") else {
            driver.closeAnyMenu()
            return
        }
        Timing.pause(Timing.animation)
        reporter.check(
            driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 2) == nil,
            "PLACES section disappeared after Hide")

        driver.menuPick("View", path: ["Sidebar", "Places"], "View ▸ Sidebar ▸ Places (re-show)")
        Timing.pause(Timing.animation)
        reporter.check(
            driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 3) != nil,
            "PLACES section re-shown from the View ▸ Sidebar menu")
    }

    func featKeyboardSelectionNav() {
        reporter.beginFeature("Keyboard selection navigation (arrow keys)")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        let firstSelected = driver.fileRow(workspace.alphaFile)?.isSelected ?? false
        reporter.check(firstSelected, "clicked row reports the AX 'selected' trait")

        driver.key(Keyboard.downArrow)
        Timing.pause(Timing.settle)
        let movedOff = !(driver.fileRow(workspace.alphaFile)?.isSelected ?? true)
        let somethingElseSelected = driver.app.firstDescendant(where: AXMatch(predicate: { element in
            element.isSelected && !element.descriptionText.isEmpty && element.descriptionText != workspace.alphaFile
        }), maxDepth: 14) != nil
        reporter.check(movedOff && somethingElseSelected, "↓ moved the selection to another row")
    }

    func featDirectoryTreeDrillIn() {
        reporter.beginFeature("Directory Tree — drill into a child node")
        guard let section = driver.find(AXMatch(identifier: "Section_DIRECTORY_TREE"), timeout: 3) else {
            reporter.fail("DIRECTORY TREE section not found")
            return
        }
        if (section.stringValue ?? "").lowercased().contains("expand") {
            driver.tapElement(section)
            Timing.pause(Timing.animation)
        }
        guard let root = driver.find(AXMatch(role: "AXButton", textContains: "macintosh hd"), timeout: 4) else {
            reporter.fail("no 'Macintosh HD' root node under the tree")
            return
        }
        driver.tapElement(root)
        Timing.pause(Timing.animation)
        guard let applications = driver.find(AXMatch(role: "AXButton", textEquals: "Applications"), timeout: 3) else {
            reporter.fail("root node did not expand to show the 'Applications' child")
            return
        }
        driver.tapElement(applications)
        Timing.pause(Timing.animation)
        reporter.check(
            driver.find(AXMatch(role: "AXButton", textContains: ".app"), timeout: 6) != nil
                && driver.fileRow(workspace.alphaFile, timeout: 1) == nil,
            "clicking tree child 'Applications' navigated the content pane to /Applications")
        driver.navigateToWorkspace()
    }

    func featSmartFoldersSectionRenders() {
        reporter.beginFeature("Smart Folders section renders")
        // The section only appears once at least one smart folder is saved (there is no
        // View ▸ Sidebar toggle for it). featSmartFolderRoundTrip covers the populated case;
        // here just confirm the sidebar itself renders its other sections.
        let smart = driver.find(AXMatch(identifier: "Section_SMART_FOLDERS"), timeout: 2)
        if smart != nil {
            reporter.pass("SMART FOLDERS section present")
        } else {
            reporter.check(
                driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 2) != nil,
                "sidebar renders (SMART FOLDERS appears after a folder is saved — see round-trip step)")
        }
    }

    // MARK: - Navigation

    func featPathBarNavigation() {
        reporter.beginFeature("Path bar navigation")
        let parent = workspace.root.deletingLastPathComponent().path
        let navigated = driver.navigateToPath(parent, expectRow: "Downloads")
        reporter.check(
            navigated && driver.fileRow(workspace.alphaFile, timeout: 1) == nil,
            "typing a path + ⏎ navigated there (now showing the 'Downloads' folder, workspace files gone)")
        driver.navigateToWorkspace()
    }

    func featBackForwardEnclosing() {
        reporter.beginFeature("Go ▸ Back / Forward / Enclosing Folder")
        driver.navigateToWorkspace()
        // Put a marker file inside the subfolder so "are we in sub-uitest" is a content check.
        let marker = "in-sub-uitest.txt"
        try? "x".write(to: workspace.url(workspace.subFolder).appendingPathComponent(marker), atomically: true, encoding: .utf8)

        driver.openRow(workspace.subFolder)
        reporter.check(
            driver.fileRow(marker, timeout: 5) != nil && driver.fileRow(workspace.alphaFile, timeout: 1) == nil,
            "opened into '\(workspace.subFolder)'")

        driver.menuPick("Go", itemContains: "Back", "Go ▸ Back")
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile, timeout: 5) != nil, "Back returned to Downloads")

        driver.menuPick("Go", itemContains: "Forward", "Go ▸ Forward")
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(marker, timeout: 5) != nil, "Forward returned into the subfolder")

        // From the subfolder, go up twice: sub-uitest → Downloads → its container (holds "Downloads").
        driver.menuPick("Go", itemContains: "Enclosing Folder", "Go ▸ Enclosing Folder")
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile, timeout: 5) != nil, "Enclosing Folder went up to Downloads")
        driver.menuPick("Go", itemContains: "Enclosing Folder", "Go ▸ Enclosing Folder (again)")
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow("Downloads", timeout: 5) != nil, "another Enclosing Folder reveals the 'Downloads' folder itself")

        try? FileManager.default.removeItem(at: workspace.url(workspace.subFolder).appendingPathComponent(marker))
        driver.navigateToWorkspace()
    }

    // MARK: - Content operations

    func featNewFolderInlineRename() {
        reporter.beginFeature("New Folder (⇧⌘N) + inline rename")
        driver.navigateToWorkspace()
        driver.menuPick("File", itemContains: "New Folder", "File ▸ New Folder")
        Timing.pause(Timing.settle)
        guard driver.commitInlineRename(to: "PlanFolder") else { return }
        reporter.check(
            workspace.waitForExistence("PlanFolder", shouldExist: true, timeout: 5),
            "new folder committed to disk as 'PlanFolder'")
        try? FileManager.default.removeItem(at: workspace.url("PlanFolder"))
    }

    func featNewFileInlineRename() {
        reporter.beginFeature("New File (⌘⌥N) + inline rename")
        driver.navigateToWorkspace()
        driver.menuPick("File", itemContains: "New File", "File ▸ New File")
        Timing.pause(Timing.settle)
        guard driver.commitInlineRename(to: "PlanFile.txt") else { return }
        reporter.check(
            workspace.waitForExistence("PlanFile.txt", shouldExist: true, timeout: 5),
            "new file committed to disk as 'PlanFile.txt'")
        try? FileManager.default.removeItem(at: workspace.url("PlanFile.txt"))
    }

    func featRenameUndoRedo() {
        reporter.beginFeature("Rename + Undo/Redo round-trip")
        driver.navigateToWorkspace()
        let original = workspace.alphaFile
        let renamed = "alpha-renamed.txt"
        guard driver.openContextItem(onFileRow: original, containing: "rename", "context ▸ Rename") else { return }
        guard driver.commitInlineRename(to: renamed) else { return }
        reporter.check(
            workspace.waitForExistence(renamed, shouldExist: true, timeout: 5)
                && !workspace.exists(original),
            "file renamed on disk '\(original)' → '\(renamed)'")

        driver.menuPick("Edit", itemContains: "Undo", "Edit ▸ Undo")
        reporter.check(
            workspace.waitForExistence(original, shouldExist: true, timeout: 5),
            "Undo restored the original name")

        driver.menuPick("Edit", itemContains: "Redo", "Edit ▸ Redo")
        reporter.check(
            workspace.waitForExistence(renamed, shouldExist: true, timeout: 5),
            "Redo re-applied the rename")

        driver.menuPick("Edit", itemContains: "Undo", "Edit ▸ Undo (restore)")
        _ = workspace.waitForExistence(original, shouldExist: true, timeout: 5)
    }

    func featCutPaste() {
        reporter.beginFeature("Cut / Paste into a subfolder")
        driver.navigateToWorkspace()
        driver.clickRow(workspace.betaFile)
        Timing.pause(Timing.brief)
        driver.chord("x", .command)
        Timing.pause(Timing.brief)
        driver.openRow(workspace.subFolder)
        driver.chord("v", .command)
        Timing.pause(Timing.animation)
        let moved = FileManager.default.fileExists(atPath: workspace.url(workspace.subFolder).appendingPathComponent(workspace.betaFile).path)
        reporter.check(moved && !workspace.exists(workspace.betaFile), "Cut+Paste moved the file into '\(workspace.subFolder)'")

        // Restore for later steps.
        let from = workspace.url(workspace.subFolder).appendingPathComponent(workspace.betaFile)
        try? FileManager.default.moveItem(at: from, to: workspace.url(workspace.betaFile))
        driver.navigateToWorkspace()
    }

    func featCopyPaste() {
        reporter.beginFeature("Copy / Paste — duplicate")
        driver.navigateToWorkspace()
        driver.clickRow(workspace.alphaFile)
        Timing.pause(Timing.brief)
        driver.chord("c", .command)
        Timing.pause(Timing.brief)
        driver.chord("v", .command)
        Timing.pause(Timing.animation)
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? []
        let base = (workspace.alphaFile as NSString).deletingPathExtension
        let duplicate = contents.first { $0 != workspace.alphaFile && $0.hasPrefix(base) && $0.hasSuffix(".txt") }
        reporter.check(duplicate != nil, "Copy+Paste created a duplicate ('\(duplicate ?? "none")')")
        if let duplicate {
            try? FileManager.default.removeItem(at: workspace.url(duplicate))
        }
    }

    func featSortOrder() {
        reporter.beginFeature("Sort order")
        driver.navigateToWorkspace()
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        let byName = firstContentRowLabel()
        driver.menuPick("View", path: ["Sort By", "Size"], "View ▸ Sort By ▸ Size")
        Timing.pause(Timing.animation)
        let bySize = firstContentRowLabel()
        driver.menuPick("View", itemContains: "Ascending", "View ▸ Ascending (toggle)")
        Timing.pause(Timing.animation)
        let bySizeReversed = firstContentRowLabel()
        reporter.check(
            !byName.isEmpty && (byName != bySize || bySize != bySizeReversed),
            "changing sort field / direction reorders the list (name:'\(byName)' size:'\(bySize)' rev:'\(bySizeReversed)')")
        driver.menuPick("View", itemContains: "Ascending", "View ▸ Ascending (restore)")
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name (restore)")
    }

    func featIconZoom() {
        reporter.beginFeature("Icon-size zoom (⌘+ / ⌘−)")
        driver.navigateToWorkspace()
        driver.tap(AXMatch(identifier: "View Mode"), "view mode")
        Timing.pause(Timing.settle)
        driver.tap(AXMatch(identifier: "ViewModeGrid"), "grid")
        Timing.pause(Timing.animation)
        let before = driver.fileRow(workspace.alphaFile)?.frame.height ?? 0
        driver.chord("=", .command)
        driver.chord("=", .command)
        Timing.pause(Timing.animation)
        let after = driver.fileRow(workspace.alphaFile)?.frame.height ?? 0
        reporter.check(before > 0 && after > before, "⌘+ grew the grid cell (\(Int(before))pt → \(Int(after))pt)")
        driver.chord("-", .command)
        driver.chord("-", .command)
        Timing.pause(Timing.animation)
        driver.tap(AXMatch(identifier: "View Mode"), "view mode")
        Timing.pause(Timing.settle)
        driver.tap(AXMatch(identifier: "ViewModeList"), "list")
    }

    func featQuickLook() {
        reporter.beginFeature("Quick Look (Space)")
        driver.navigateToWorkspace()
        driver.clickRow(workspace.alphaFile)
        Timing.pause(Timing.brief)
        let before = driver.app.windows.count
        driver.key(Keyboard.space)
        Timing.pause(Timing.animation)
        let opened = driver.app.windows.count > before
            || driver.app.firstDescendant(where: AXMatch(textContains: workspace.alphaFile), maxDepth: 6) != nil
        reporter.check(opened, "Space opened a Quick Look panel")
        driver.key(Keyboard.space)
        Timing.pause(Timing.settle)
    }

    func featEmptyDirectory() {
        reporter.beginFeature("Empty-directory view")
        let emptyDir = workspace.url("EmptyPlan")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        driver.navigateToPath(emptyDir.path)
        reporter.check(
            driver.find(AXMatch(textContains: "this folder is empty"), timeout: 5) != nil,
            "empty folder shows the 'This Folder is Empty' view")
        driver.navigateToWorkspace()
        try? FileManager.default.removeItem(at: emptyDir)
    }

    // MARK: - Footer & inspector

    func featFooterTerminalButton() {
        reporter.beginFeature("Footer terminal toggle button")
        driver.navigateToWorkspace()
        guard driver.tap(AXMatch(identifier: "terminal"), "footer terminal button", timeout: 4) else { return }
        reporter.check(
            driver.menuHasItem("View", containing: "Hide Terminal"),
            "footer button opened the terminal drawer (View ▸ Hide Terminal offered)")
        driver.tap(AXMatch(identifier: "terminal"), "footer terminal button (restore)", timeout: 4)
    }

    func featTogglePreview() {
        reporter.beginFeature("Toggle Preview")
        driver.navigateToWorkspace()
        driver.clickRow(workspace.alphaFile)
        guard driver.menuPick("View", itemContains: "Show Preview", "View ▸ Show Preview") else { return }
        reporter.check(
            driver.menuHasItem("View", containing: "Hide Preview"),
            "preview pane is showing (View ▸ Hide Preview offered)")
        driver.menuPick("View", itemContains: "Hide Preview", "View ▸ Hide Preview (restore)")
    }

    // MARK: - Modals

    func featSettingsTabs() {
        reporter.beginFeature("Settings — every tab switches")
        let tabProbe: [(String, String)] = [
            ("General", "Language"),
            ("Appearance", "Theme"),
            ("Sidebar", "Show Tags"),
            ("Advanced", ""),
        ]
        for (index, probe) in tabProbe.enumerated() {
            guard driver.openSettings(tab: probe.0) else { continue }
            if probe.1.isEmpty {
                reporter.check(driver.sheet() != nil, "Settings ▸ \(probe.0) tab selected")
            } else {
                reporter.check(
                    driver.sheet()?.firstDescendant(where: AXMatch(textContains: probe.1.lowercased())) != nil,
                    "Settings ▸ \(probe.0) shows its content ('\(probe.1)')")
            }
            if index == tabProbe.count - 1 { driver.dismissSheet() }
        }
    }

    func featHelpSheet() {
        reporter.beginFeature("Help sheet (⌘?)")
        guard driver.menuPick("Help", itemContains: "Help", "Help ▸ Help") else { return }
        reporter.check(driver.waitForSheet(), "Help sheet opened")
        reporter.check(driver.dismissSheet(), "Help sheet dismissed")
    }

    func featShortcutsHUD() {
        reporter.beginFeature("Shortcuts HUD")
        guard driver.menuPick("Help", itemContains: "Shortcuts", "Help ▸ Shortcuts") else { return }
        let shown = driver.waitForSheet()
            || driver.find(AXMatch(textContains: "shortcuts"), timeout: 3) != nil
        reporter.check(shown, "Shortcuts overlay opened")
        driver.key(Keyboard.escape)
        Timing.pause(Timing.settle)
        driver.dismissSheet()
    }

    func featAboutSheet() {
        reporter.beginFeature("About sheet")
        guard driver.menuPick("Wiles", itemContains: "About Wiles", "Wiles ▸ About Wiles") else { return }
        reporter.check(driver.waitForSheet(), "About sheet opened")
        reporter.check(driver.dismissSheet(), "About sheet dismissed")
    }

    func featFeedbackSheet() {
        reporter.beginFeature("Feedback sheet")
        guard driver.menuPick("Help", itemContains: "Send Feedback", "Help ▸ Send Feedback") else { return }
        reporter.check(driver.waitForSheet(), "Feedback sheet opened")
        reporter.check(driver.dismissSheet(), "Feedback sheet dismissed")
    }
}
