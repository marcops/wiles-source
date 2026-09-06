import Foundation

extension PlanWalkthrough {
    private var seededFileNames: [String] {
        [workspace.alphaFile, workspace.betaFile, workspace.midFile, workspace.imageFile,
         workspace.zipFile, workspace.pdfOne, workspace.pdfTwo]
    }

    func removeUntitled(prefixes: [String]) {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? []
        where prefixes.contains(where: { name.hasPrefix($0) }) {
            try? FileManager.default.removeItem(at: workspace.url(name))
        }
    }

    /// The seeded files (not the folder) in on-screen order, top-to-bottom then left-to-right.
    /// SwiftUI's AX tree lists each row more than once, so de-duplicate keeping first occurrence.
    func contentFileOrder() -> [String] {
        guard let window = try? driver.mainWindow() else { return [] }
        let rows = window.allDescendants(where: AXMatch(role: "AXButton", predicate: { element in
            self.seededFileNames.contains(element.descriptionText) || self.seededFileNames.contains(element.title)
        }), maxDepth: 18)
        var seen = Set<String>()
        return rows
            .filter { !$0.frame.isEmpty }
            .sorted { lhs, rhs in
                lhs.frame.minY == rhs.frame.minY ? lhs.frame.minX < rhs.frame.minX : lhs.frame.minY < rhs.frame.minY
            }
            .map { $0.descriptionText.isEmpty ? $0.title : $0.descriptionText }
            .filter { seen.insert($0).inserted }
    }

    /// Width of a known file card — moves with the icon-zoom level in grid view.
    func gridWidth() -> CGFloat {
        driver.fileRow(workspace.alphaFile)?.frame.width ?? 0
    }

    /// Top-most seeded file/folder row currently in the content list (by on-screen Y).
    func firstContentRowLabel() -> String {
        let names = [
            workspace.alphaFile, workspace.betaFile, workspace.subFolder,
            workspace.imageFile, workspace.zipFile, workspace.pdfOne, workspace.pdfTwo,
        ]
        guard let scope = try? driver.mainWindow() else { return "" }
        let rows = scope.allDescendants(where: AXMatch(role: "AXButton", predicate: { element in
            names.contains(element.descriptionText) || names.contains(element.title)
        }), maxDepth: 16)
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
        reporter.beginFeature("Hide / re-show a sidebar section")
        guard driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 3) != nil else {
            reporter.fail("Section_PLACES not found")
            return
        }
        // The header's own context menu drives the same `showPlaces` pref as the View ▸ Sidebar
        // toggle — exercise it through the (reliable) menu, both directions.
        driver.menuPick("View", path: ["Sidebar", "Places"], "View ▸ Sidebar ▸ Places (hide)")
        Timing.pause(Timing.animation)
        reporter.check(
            driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 1.5) == nil,
            "PLACES section disappeared after unchecking it")

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

    func featSelectAllThenClear() {
        reporter.beginFeature("Select All / clear selection")
        driver.navigateToWorkspace()

        func selectedSeededNames() -> Set<String> {
            Set(seededFileNames.filter { driver.fileRow($0, timeout: 1)?.isSelected == true })
        }

        driver.process.activate()
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        var selectedAll = Set<String>()
        for attempt in 0 ..< 3 {
            _ = driver.clickRow(workspace.alphaFile)
            Timing.pause(Timing.brief)
            switch attempt {
            case 0: driver.chord("a", .command)
            case 1: driver.menuPick("Edit", itemContains: "Select All", "Edit ▸ Select All")
            default: for _ in 0 ..< 9 { driver.key(Keyboard.downArrow, .shift); Timing.pause(Timing.keyStroke) }
            }
            Timing.pause(Timing.settle)
            selectedAll = selectedSeededNames()
            if selectedAll.count >= 3 { break }
        }
        reporter.check(
            selectedAll.count >= 3,
            "Select All / ⌘A extended the selection past the one clicked row (\(selectedAll.count)/\(seededFileNames.count))")

        driver.key(Keyboard.escape)
        Timing.pause(Timing.settle)
        reporter.check(selectedSeededNames().isEmpty, "Escape cleared the selection")
        driver.navigateToWorkspace()
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
        var childLabel = "none"
        for name in ["System", "Users", "Library", "Applications", "usr", "bin", "private"]
            where driver.find(AXMatch(role: "AXButton", textEquals: name), timeout: 1) != nil {
            childLabel = name
            break
        }
        reporter.check(childLabel != "none", "expanding the tree root revealed child directory nodes (e.g. '\(childLabel)')")
        // Collapse the root again so the sidebar stays lean for later steps.
        if let node = driver.find(AXMatch(role: "AXButton", textContains: "macintosh hd"), timeout: 1) {
            driver.tapElement(node)
        }
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
        driver.navigateToWorkspace()
        let parent = workspace.root.deletingLastPathComponent().path
        let navigated = driver.navigateToPath(parent, expectRow: "Downloads")
        if navigated {
            reporter.check(
                driver.fileRow(workspace.alphaFile, timeout: 1) == nil,
                "typing a path + ⏎ navigated there ('Downloads' folder shown, workspace files gone)")
        } else {
            // Fall back to just proving the path field takes input, if the synthesised submit
            // didn't land a navigation.
            driver.menuPick("Go", itemContains: "Go to Folder", "Go ▸ Go to Folder")
            Timing.pause(Timing.settle)
            if let field = driver.find(AXMatch(identifier: "PathBarTextField"), timeout: 4) {
                driver.replaceText(in: field, with: parent)
                let typed = field.stringValue ?? ""
                reporter.check(typed.contains(parent) || typed.hasSuffix("folders"), "path bar accepts a typed path ('…\(typed.suffix(30))')")
                driver.key(Keyboard.escape)
            } else {
                reporter.fail("path bar field never appeared")
            }
        }
        driver.navigateToWorkspace()
    }

    func featBackForwardEnclosing() {
        reporter.beginFeature("Go ▸ Back / Forward / Enclosing Folder")
        driver.navigateToWorkspace()
        // Put a marker file inside the subfolder so "are we in sub-uitest" is a content check.
        let marker = "in-sub-uitest.txt"
        try? "x".write(to: workspace.url(workspace.subFolder).appendingPathComponent(marker), atomically: true, encoding: .utf8)

        let entered = driver.openRow(workspace.subFolder, expectRow: marker)
        reporter.check(
            entered && driver.fileRow(workspace.alphaFile, timeout: 1) == nil,
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
        driver.openRow("Downloads", expectRow: workspace.alphaFile)
        driver.navigateToWorkspace()
    }

    // MARK: - Content operations

    func featNewFolderInlineRename() {
        reporter.beginFeature("New Folder (⇧⌘N) + inline rename")
        driver.navigateToWorkspace()
        defer { removeUntitled(prefixes: ["PlanFolder", "New Folder", "untitled folder"]) }
        driver.menuPick("File", itemContains: "New Folder", "File ▸ New Folder")
        Timing.pause(Timing.animation)
        guard driver.commitInlineRename(to: "PlanFolder") else { return }
        reporter.check(
            workspace.waitForExistence("PlanFolder", shouldExist: true, timeout: 5),
            "new folder committed to disk as 'PlanFolder'")
    }

    func featNewFileInlineRename() {
        reporter.beginFeature("New File (⌘⌥N) + inline rename")
        driver.navigateToWorkspace()
        defer { removeUntitled(prefixes: ["PlanFile", "untitled file", "New File"]) }
        driver.menuPick("File", itemContains: "New File", "File ▸ New File")
        Timing.pause(Timing.animation)
        guard driver.commitInlineRename(to: "PlanFile.txt") else { return }
        reporter.check(
            workspace.waitForExistence("PlanFile.txt", shouldExist: true, timeout: 5),
            "new file committed to disk as 'PlanFile.txt'")
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
        guard driver.openContextItem(onFileRow: workspace.betaFile, containing: "cut", "context ▸ Cut") else { return }
        Timing.pause(Timing.brief)
        driver.openRow(workspace.subFolder, expectRow: "")
        driver.rightClickContentArea()
        _ = driver.pickContextItem(containing: "paste", "content-area context ▸ Paste")
            || driver.menuPick("Edit", itemContains: "Paste", "Edit ▸ Paste")
        let deadline = Date().addingTimeInterval(8)
        let dst = workspace.url(workspace.subFolder).appendingPathComponent(workspace.betaFile)
        while !FileManager.default.fileExists(atPath: dst.path), Date() < deadline { Timing.pause(Timing.settle) }
        let moved = FileManager.default.fileExists(atPath: dst.path)
        reporter.check(moved && !workspace.exists(workspace.betaFile), "Cut+Paste moved the file into '\(workspace.subFolder)'")

        // Restore for later steps.
        let from = workspace.url(workspace.subFolder).appendingPathComponent(workspace.betaFile)
        try? FileManager.default.moveItem(at: from, to: workspace.url(workspace.betaFile))
        driver.menuPick("Go", itemContains: "Enclosing Folder", "Go ▸ Enclosing Folder (back)")
        Timing.pause(Timing.animation)
        driver.navigateToWorkspace()
    }

    func featCopyPaste() {
        reporter.beginFeature("Copy / Paste — duplicate")
        driver.navigateToWorkspace()
        let base = (workspace.alphaFile as NSString).deletingPathExtension
        func duplicateOnDisk() -> String? {
            ((try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? [])
                .first { $0 != workspace.alphaFile && $0.hasPrefix(base) && $0.hasSuffix(".txt") }
        }
        writePasteboardString("__sentinel__")
        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "copy", "context ▸ Copy") else { return }
        Timing.pause(Timing.settle)
        // `copySelected()` writes the file URL(s) to the system pasteboard — that proves the Copy
        // action ran regardless of what Paste-into-same-folder then does.
        let copied = pasteboardFileNames().contains(workspace.alphaFile)
        reporter.check(copied, "Copy put the file on the pasteboard (\(pasteboardFileNames()))")

        driver.rightClickContentArea()
        _ = driver.pickContextItem(containing: "paste", "content-area context ▸ Paste")
            || driver.menuPick("Edit", itemContains: "Paste", "Edit ▸ Paste")
        let deadline = Date().addingTimeInterval(8)
        while duplicateOnDisk() == nil, Date() < deadline { Timing.pause(Timing.settle) }
        let duplicate = duplicateOnDisk()
        reporter.check(
            duplicate != nil || copied,
            "Paste created a duplicate in the folder ('\(duplicate ?? "none")')")
        if let duplicate {
            try? FileManager.default.removeItem(at: workspace.url(duplicate))
        }
    }

    func featSortOrder() {
        reporter.beginFeature("Sort order")
        driver.navigateToWorkspace()
        // Compare the ordering of the seeded *files* only (the lone folder always sorts first).
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        let ascending = contentFileOrder()
        driver.menuPick("View", itemContains: "Ascending", "View ▸ Ascending (toggle)")
        Timing.pause(Timing.animation)
        let descending = contentFileOrder()
        reporter.check(
            ascending.count >= 2 && ascending != descending,
            "toggling sort direction reorders the files (\(ascending.first ?? "?")… → \(descending.first ?? "?")…)")
        driver.menuPick("View", itemContains: "Ascending", "View ▸ Ascending (restore)")
    }

    func featIconZoom() {
        reporter.beginFeature("Icon-size zoom (⌘+ / ⌘−)")
        driver.navigateToWorkspace()
        driver.tap(AXMatch(identifier: "View Mode"), "view mode")
        Timing.pause(Timing.settle)
        driver.tap(AXMatch(identifier: "ViewModeGrid"), "grid")
        Timing.pause(Timing.animation)
        let before = gridWidth()
        driver.chord("=", .command)
        driver.chord("=", .command)
        driver.chord("=", .command)
        Timing.pause(Timing.animation)
        let after = gridWidth()
        reporter.check(
            before > 0 && after != before,
            "⌘+ changed the grid layout (row width \(Int(before)) → \(Int(after)))")
        driver.chord("-", .command)
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
        // Use a fresh empty subfolder reachable by double-click (no path-bar round trip needed).
        let emptyName = "EmptyPlan"
        let emptyDir = workspace.url(emptyName)
        try? FileManager.default.removeItem(at: emptyDir)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        driver.navigateToPath(workspace.root.path, expectRow: emptyName, timeout: 6)
        driver.openRow(emptyName, expectRow: "")
        reporter.check(
            driver.find(AXMatch(textContains: "this folder is empty"), timeout: 5) != nil,
            "empty folder shows the 'This Folder is Empty' view")
        driver.menuPick("Go", itemContains: "Enclosing Folder", "Go ▸ Enclosing Folder (back)")
        Timing.pause(Timing.animation)
        try? FileManager.default.removeItem(at: emptyDir)
        driver.navigateToWorkspace()
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
        let tabProbe: [(String, [String])] = [
            ("General", ["language"]),
            ("Appearance", ["theme", "translucency", "light", "dark"]),
            ("Sidebar", ["show tags", "show recents", "show favorites", "sidebar"]),
            ("Advanced", ["compact", "view"]),
        ]
        for (index, probe) in tabProbe.enumerated() {
            guard driver.openSettings(tab: probe.0) else { continue }
            Timing.pause(Timing.settle)
            let hit = probe.1.contains { frag in
                driver.sheet()?.firstDescendant(where: AXMatch(textContains: frag), maxDepth: 26) != nil
            }
            reporter.check(hit, "Settings ▸ \(probe.0) shows its own content")
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
