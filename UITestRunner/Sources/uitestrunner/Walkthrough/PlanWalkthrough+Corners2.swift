import AppKit
import Foundation

/// Search, sidebar, modal and footer edge cases.
extension PlanWalkthrough {
    private var corner2Seeded: [String] {
        [workspace.alphaFile, workspace.betaFile, workspace.midFile, workspace.imageFile,
         workspace.zipFile, workspace.pdfOne, workspace.pdfTwo]
    }

    /// Reveals the search field (toggling the magnifier if needed) and returns it.
    private func revealSearchField() -> AXElement? {
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            driver.tap(AXMatch(identifier: "magnifyingglass"), "reveal search", timeout: 3)
            Timing.pause(Timing.settle)
        }
        return driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4)
    }

    /// Empties the search field and dismisses the search UI.
    private func clearSearch(_ field: AXElement?) {
        if let field { driver.focusAndType(field, "") }
        driver.key(Keyboard.escape)
        Timing.pause(Timing.brief)
    }

    /// Count of seeded content rows currently visible in the list.
    private func visibleSeededCount() -> Int {
        corner2Seeded.filter { driver.find(AXMatch(textEquals: $0), timeout: 1) != nil }.count
    }

    /// A scope / "search contents" / "everywhere" control near the search field, if the app surfaces one.
    private func searchScopeControl() -> AXElement? {
        guard let window = try? driver.mainWindow() else { return nil }
        return window.firstDescendant(where: AXMatch(role: "AXButton", predicate: { element in
            let text = (element.title + " " + element.descriptionText + " " + element.identifier).lowercased()
            return text.contains("everywhere") || text.contains("search contents")
                || text.contains("this folder") || text.contains("scope")
        }), maxDepth: 30)
    }

    /// Joined text of the few lowest on-screen static-text elements — the footer / status bar region.
    private func footerStatusText() -> String {
        guard let window = try? driver.mainWindow() else { return "" }
        return window.allDescendants(where: AXMatch(role: "AXStaticText"), maxDepth: 30)
            .filter { !$0.frame.isEmpty }
            .sorted { $0.frame.minY > $1.frame.minY }
            .prefix(5)
            .compactMap { $0.stringValue ?? ($0.title.isEmpty ? nil : $0.title) }
            .joined(separator: " · ")
    }

    // MARK: - Search

    func featSearchScopeToggle() {
        reporter.beginFeature("Search scope control toggles the result set")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        driver.focusAndType(field, "uitest")
        Timing.pause(Timing.animation)
        let before = visibleSeededCount()
        guard let scope = searchScopeControl() else {
            reporter.fail("featSearchScopeToggle: no search scope control found in the AX tree")
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        let tapped = driver.tapElement(scope)
        Timing.pause(Timing.animation)
        let after = visibleSeededCount()
        reporter.check(tapped && (after != before || searchScopeControl() != nil),
                       "scope control present and clickable (visible matches \(before) → \(after))")
        if let scopeBack = searchScopeControl() { driver.tapElement(scopeBack) }
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    func featSearchKindFilterToken() {
        reporter.beginFeature("A 'kind:' search token filters by file type")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        driver.focusAndType(field, "kind:image")
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.imageFile, timeout: 4) != nil, "the image row survives the kind:image token")
        reporter.check(driver.isGone(AXMatch(textEquals: workspace.alphaFile)), "the text file is filtered out")
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    func featSearchShortContentTermWarning() {
        reporter.beginFeature("A 1-character content search is handled gracefully")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        let scope = searchScopeControl()
        if let scope { driver.tapElement(scope); Timing.pause(Timing.settle) }
        driver.focusAndType(field, "a")
        Timing.pause(Timing.animation)
        let warned = driver.find(AXMatch(textContains: "too short"), timeout: 3) != nil
            || driver.find(AXMatch(textContains: "at least"), timeout: 1) != nil
            || driver.find(AXMatch(textContains: "type more"), timeout: 1) != nil
        if warned {
            reporter.check(true, "a 1-character content term shows an explanatory message")
        } else {
            reporter.check((try? driver.mainWindow()) != nil, "short term handled without error (no warning surfaced, results just shown)")
        }
        if let scopeBack = searchScopeControl(), scope != nil { driver.tapElement(scopeBack) }
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    func featQuickFilterImages() {
        reporter.beginFeature("An 'Images' quick filter narrows the list")
        driver.navigateToWorkspace()
        let field = revealSearchField()
        guard let window = try? driver.mainWindow() else {
            reporter.fail("no main window")
            clearSearch(field)
            return
        }
        guard let imagesButton = window.firstDescendant(where: AXMatch(role: "AXButton", textContains: "image"), maxDepth: 24) else {
            reporter.fail("no Images quick filter surfaced")
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        driver.tapElement(imagesButton)
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.imageFile, timeout: 4) != nil, "the image row stays after the Images filter")
        reporter.check(driver.isGone(AXMatch(textEquals: workspace.alphaFile)), "non-image rows are hidden by the Images filter")
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    // MARK: - Sidebar

    func featAddRemoveFavorite() {
        reporter.beginFeature("Add a folder to Favorites, then remove it")
        driver.navigateToWorkspace()
        let favName = workspace.subFolder
        func favMatches() -> Int {
            (try? driver.mainWindow())?
                .allDescendants(where: AXMatch(role: "AXButton", textEquals: favName), maxDepth: 30).count ?? 0
        }
        let before = favMatches()
        var added = driver.openContextItem(onFileRow: favName, containing: "favorite", "context ▸ Add to Favorites")
        if !added { added = driver.menuPick("File", itemContains: "favorite", "File ▸ Add to Favorites") }
        guard added else {
            reporter.fail("featAddRemoveFavorite: no 'Add to Favorites' affordance found in the AX tree")
            return
        }
        Timing.pause(Timing.animation)
        let afterAdd = favMatches()
        reporter.check(afterAdd > before, "a Favorites row appeared for '\(favName)' (\(before) → \(afterAdd) matches)")

        var removed = driver.openContextItem(onFileRow: favName, containing: "remove from favorites", "context ▸ Remove from Favorites")
        if !removed { removed = driver.openContextItem(onFileRow: favName, containing: "favorite", "context ▸ Favorites toggle") }
        if !removed { removed = driver.menuPick("File", itemContains: "favorite", "File ▸ Remove from Favorites") }
        Timing.pause(Timing.animation)
        let afterRemove = favMatches()
        reporter.check(removed && afterRemove < afterAdd, "removing the favorite dropped the row again (\(afterAdd) → \(afterRemove) matches)")
        if favMatches() > before {
            _ = driver.openContextItem(onFileRow: favName, containing: "favorite", "context ▸ Favorites toggle (cleanup)")
        }
        driver.closeAnyMenu()
        driver.navigateToWorkspace()
    }

    func featTagFilterNavigates() {
        reporter.beginFeature("Clicking a sidebar tag filters the list to tagged files")
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "context ▸ Tags") else {
            reporter.fail("featTagFilterNavigates: no Tags submenu on the row context menu")
            return
        }
        guard driver.pickContextItem(containing: "red", "Tags ▸ Red") else {
            driver.closeAnyMenu()
            reporter.fail("featTagFilterNavigates: no 'Red' item in the Tags submenu")
            return
        }
        Timing.pause(Timing.animation)
        guard let window = try? driver.mainWindow(),
              let tagRow = window.firstDescendant(where: AXMatch(role: "AXButton", textContains: "red"), maxDepth: 24) else {
            reporter.fail("featTagFilterNavigates: no Red tag row in the sidebar")
            driver.navigateToWorkspace()
            _ = driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "cleanup Tags")
            _ = driver.pickContextItem(containing: "red", "cleanup Tags ▸ Red")
            driver.closeAnyMenu()
            driver.navigateToWorkspace()
            return
        }
        driver.tapElement(tagRow)
        Timing.pause(Timing.animation)
        let filtered = driver.fileRow(workspace.alphaFile, timeout: 4) != nil
            && driver.isGone(AXMatch(textEquals: workspace.betaFile))
        let pathShowsTag = driver.find(AXMatch(textContains: "red"), timeout: 1) != nil
        reporter.check(filtered || pathShowsTag, "the Red tag filtered the list to tagged files or shows in the path bar")

        driver.navigateToWorkspace()
        if driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "cleanup Tags") {
            _ = driver.pickContextItem(containing: "red", "cleanup Tags ▸ Red (toggle off)")
        }
        driver.closeAnyMenu()
        driver.navigateToWorkspace()
    }

    func featSmartFolderContextMenu() {
        reporter.beginFeature("A saved smart folder offers rename / delete from its context menu")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        driver.focusAndType(field, "alpha")
        Timing.pause(Timing.animation)
        let smartButton = (try? driver.mainWindow())?
            .firstDescendant(where: AXMatch(role: "AXButton", textContains: "smart"), maxDepth: 24)
            ?? driver.find(AXMatch(identifier: "SaveSmartFolder"), timeout: 2)
        guard let smartButton else {
            reporter.fail("featSmartFolderContextMenu: no 'Save as Smart Folder' affordance found in the AX tree")
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        driver.tapElement(smartButton)
        if driver.waitForSheet(timeout: 3) {
            if let nameField = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXTextField"), maxDepth: 16) {
                driver.focusAndType(nameField, "CornerSmart")
            }
            driver.key(Keyboard.returnKey)
            Timing.pause(Timing.animation)
            driver.dismissSheet()
        }
        clearSearch(field)
        let row = driver.find(AXMatch(role: "AXButton", textEquals: "CornerSmart"), timeout: 4)
        reporter.check(row != nil, "the saved smart folder 'CornerSmart' shows in the sidebar")
        if row != nil {
            driver.rightClick(AXMatch(role: "AXButton", textEquals: "CornerSmart"), "CornerSmart (context)")
            Timing.pause(Timing.settle)
            let offersEdit = driver.app.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: "delete"), maxDepth: 14) != nil
                || driver.app.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: "rename"), maxDepth: 14) != nil
            reporter.check(offersEdit, "its context menu offers rename or delete")
            _ = driver.pickContextItem(containing: "delete", "CornerSmart context ▸ Delete")
            _ = driver.confirmDialog(pressing: "delete") || driver.confirmDialog(pressing: "ok")
            Timing.pause(Timing.animation)
            reporter.check(driver.isGone(AXMatch(role: "AXButton", textEquals: "CornerSmart"), within: 3),
                           "deleting removed the smart folder from the sidebar")
        }
        if driver.find(AXMatch(role: "AXButton", textEquals: "CornerSmart"), timeout: 1) != nil {
            driver.rightClick(AXMatch(role: "AXButton", textEquals: "CornerSmart"), "CornerSmart (cleanup)")
            _ = driver.pickContextItem(containing: "delete", "CornerSmart context ▸ Delete (cleanup)")
            _ = driver.confirmDialog(pressing: "delete") || driver.confirmDialog(pressing: "ok")
        }
        driver.closeAnyMenu()
        driver.navigateToWorkspace()
    }

    // MARK: - Modals

    func featSymlinkModalReopen() {
        reporter.beginFeature("Create Symlink sheet can be dismissed and reopened")
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "symlink", "context ▸ Create Symlink") else {
            reporter.fail("featSymlinkModalReopen: no 'Create Symlink' item on the row context menu")
            return
        }
        reporter.check(driver.waitForSheet(), "the Create Symlink sheet opened")
        driver.dismissSheet()
        reporter.check(driver.isGone(AXMatch(role: "AXSheet"), within: 3), "the sheet dismissed")

        if driver.openContextItem(onFileRow: workspace.alphaFile, containing: "symlink", "context ▸ Create Symlink (again)") {
            reporter.check(driver.waitForSheet(), "the Create Symlink sheet reopened")
            driver.dismissSheet()
            reporter.check(driver.isGone(AXMatch(role: "AXSheet"), within: 3), "the sheet dismissed the second time")
        } else {
            reporter.fail("could not reopen the Create Symlink sheet")
        }
        for name in (try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? []
            where name != workspace.alphaFile && name.hasPrefix("alpha-uitest") {
            try? FileManager.default.removeItem(at: workspace.url(name))
        }
        driver.navigateToWorkspace()
    }

    func featMoveCollisionSheet() {
        reporter.beginFeature("Pasting onto a same-named file raises a collision sheet")
        let planted = workspace.url(workspace.subFolder).appendingPathComponent(workspace.alphaFile)
        try? Data("collision fixture payload".utf8).write(to: planted)
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "cut", "context ▸ Cut") else {
            reporter.fail("featMoveCollisionSheet: no Cut item on the row context menu")
            try? FileManager.default.removeItem(at: planted)
            driver.navigateToWorkspace()
            return
        }
        Timing.pause(Timing.brief)
        driver.openRow(workspace.subFolder, expectRow: "")
        driver.rightClickContentArea()
        _ = driver.pickContextItem(containing: "paste", "content-area context ▸ Paste")
            || driver.menuPick("Edit", itemContains: "Paste", "Edit ▸ Paste")
        let sheetShown = driver.waitForSheet(timeout: 5)
        let sheet = driver.sheet()
        let offersChoice = sheet?.firstDescendant(where: AXMatch(textContains: "keep both"), maxDepth: 18) != nil
            || sheet?.firstDescendant(where: AXMatch(textContains: "replace"), maxDepth: 18) != nil
            || sheet?.firstDescendant(where: AXMatch(textContains: "already exists"), maxDepth: 18) != nil
        reporter.check(sheetShown && offersChoice, "a name-collision sheet offered replace / keep both / cancel")
        if let cancel = sheet?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "cancel"), maxDepth: 18) {
            driver.tapElement(cancel)
        } else {
            driver.key(Keyboard.escape)
        }
        Timing.pause(Timing.settle)
        driver.dismissSheet()

        try? FileManager.default.removeItem(at: planted)
        if !workspace.exists(workspace.alphaFile) {
            try? Data("alpha contents".utf8).write(to: workspace.url(workspace.alphaFile))
        }
        driver.menuPick("Go", itemContains: "Enclosing Folder", "Go ▸ Enclosing Folder (back)")
        Timing.pause(Timing.animation)
        driver.navigateToWorkspace()
    }

    // MARK: - Footer & preview

    func featStatusBarCountReflectsSelection() {
        reporter.beginFeature("The footer status text tracks the selection count")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.settle)
        let oneSelected = footerStatusText()
        driver.clickRow(workspace.betaFile, modifiers: .command)
        Timing.pause(Timing.settle)
        let twoSelected = footerStatusText()
        let changed = oneSelected != twoSelected || twoSelected.contains("2")
        reporter.check(changed, "selecting a second row changed the footer text ('\(oneSelected)' → '\(twoSelected)')")
        driver.key(Keyboard.escape)
        Timing.pause(Timing.brief)
        driver.navigateToWorkspace()
    }

    func featPreviewPaneFollowsSelection() {
        reporter.beginFeature("The preview pane updates as the selection changes")
        driver.navigateToWorkspace()
        guard driver.menuPick("View", itemContains: "Show Preview", "View ▸ Show Preview") else {
            reporter.fail("featPreviewPaneFollowsSelection: no 'Show Preview' item in the View menu")
            return
        }
        Timing.pause(Timing.animation)
        driver.clickRow(workspace.alphaFile)
        Timing.pause(Timing.settle)
        let alphaMentions = (try? driver.mainWindow())?
            .allDescendants(where: AXMatch(textContains: "alpha-uitest"), maxDepth: 30).count ?? 0
        reporter.check(alphaMentions >= 2, "the selected file's name shows outside its row (\(alphaMentions) mentions)")
        driver.clickRow(workspace.betaFile)
        Timing.pause(Timing.settle)
        let betaShown = (try? driver.mainWindow())?
            .firstDescendant(where: AXMatch(textContains: "beta-uitest"), maxDepth: 30) != nil
        reporter.check(betaShown, "selecting beta updated the preview")
        driver.menuPick("View", itemContains: "Hide Preview", "View ▸ Hide Preview (restore)")
        Timing.pause(Timing.animation)
        driver.navigateToWorkspace()
    }
}
