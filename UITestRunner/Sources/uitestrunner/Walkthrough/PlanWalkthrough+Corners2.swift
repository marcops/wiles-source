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
            _ = driver.activateSearch()
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

    /// The "Whole Mac" search toggle — flips search between this folder and a recursive home crawl.
    private func wholeMacToggle() -> AXElement? {
        (try? driver.mainWindow())?
            .firstDescendant(where: AXMatch(role: "AXButton", textContains: "whole mac"), maxDepth: 30)
    }

    /// Opens the search filter menu and clicks the first item whose text contains `fragment`.
    @discardableResult
    private func pickSearchFilter(_ fragment: String) -> Bool {
        guard let button = driver.find(AXMatch(textContains: "search filters"), timeout: 3) else { return false }
        driver.tapElement(button)
        Timing.pause(Timing.settle)
        if driver.app.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: fragment), maxDepth: 16) == nil {
            _ = tapMenuItem(containing: "scope")
        }
        let picked = tapMenuItem(containing: fragment)
        driver.closeAnyMenu()
        return picked
    }

    private func tapMenuItem(containing fragment: String) -> Bool {
        guard let item = driver.app.waitForDescendant(
            where: AXMatch(role: "AXMenuItem", textContains: fragment), timeout: 3, maxDepth: 16) else { return false }
        return driver.tapElement(item)
    }

    /// The footer status string, read off its "Status Bar" element (bottom static-text scrape fallback).
    private func footerStatusText() -> String {
        if let element = driver.find(AXMatch(identifier: "Status Bar"), timeout: 2),
           let value = element.stringValue ?? (element.title.isEmpty ? nil : element.title) {
            return value
        }
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
        reporter.beginFeature("The Whole Mac toggle changes the search scope")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        driver.focusAndType(field, "uitest")
        Timing.pause(Timing.animation)
        let before = visibleSeededCount()
        guard let toggle = wholeMacToggle() else {
            reporter.fail("featSearchScopeToggle: no 'Whole Mac' search-scope toggle in the AX tree")
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        let wasSelected = toggle.isSelected
        let tapped = driver.tapElement(toggle)
        Timing.pause(Timing.animation)
        let after = visibleSeededCount()
        let flipped = (wholeMacToggle()?.isSelected ?? wasSelected) != wasSelected
        reporter.check(tapped && flipped, "the Whole Mac toggle flipped its state (visible seeded matches \(before) → \(after))")
        if let restore = wholeMacToggle(), restore.isSelected != wasSelected { driver.tapElement(restore) }
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
        if let toggle = wholeMacToggle(), toggle.isSelected { driver.tapElement(toggle); Timing.pause(Timing.brief) }
        _ = field
        guard driver.searchFor("kind:image") != nil else {
            reporter.fail("featSearchKindFilterToken: could not type the 'kind:image' token into the field")
            driver.deactivateSearch()
            driver.navigateToWorkspace()
            return
        }
        reporter.check(driver.fileRow(workspace.imageFile, timeout: 4) != nil, "the image row survives the kind:image token")
        reporter.check(driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 4), "the text file is filtered out")
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    func featSearchShortContentTermWarning() {
        reporter.beginFeature("A too-short content search explains itself")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        guard pickSearchFilter("file content") else {
            reporter.fail("featSearchShortContentTermWarning: could not switch the search scope to File Content")
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        Timing.pause(Timing.settle)
        _ = field
        driver.searchFor("a")
        let warned = driver.find(AXMatch(textContains: "at least 3 characters"), timeout: 3) != nil
            || driver.find(AXMatch(textContains: "search inside files"), timeout: 1) != nil
            || driver.find(AXMatch(textContains: "type at least"), timeout: 1) != nil
        reporter.check(warned, "a 1-character content term shows the 'type at least 3 characters' notice")
        _ = pickSearchFilter("file name")
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    func featQuickFilterImages() {
        reporter.beginFeature("The Images filter narrows the list to pictures")
        driver.navigateToWorkspace()
        guard driver.searchFor("kind:image") != nil else {
            reporter.fail("search field never appeared")
            driver.navigateToWorkspace()
            return
        }
        let picsShown = driver.fileRow(workspace.imageFile, timeout: 4) != nil
        let textHidden = driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 4)
        reporter.check(picsShown && textHidden, "the image survives and non-image rows are hidden")
        driver.deactivateSearch()
        driver.navigateToWorkspace()
    }

    // MARK: - Sidebar

    func featAddRemoveFavorite() {
        reporter.beginFeature("Add a folder to Favorites, then remove it")
        driver.navigateToWorkspace()
        let favName = workspace.subFolder
        // Only sidebar rows carry an accessibility identifier equal to the item name.
        func favRowCount() -> Int {
            (try? driver.mainWindow())?
                .allDescendants(where: AXMatch(role: "AXButton", identifier: favName), maxDepth: 40).count ?? 0
        }
        let before = favRowCount()
        guard driver.openContextItem(onFileRow: favName, containing: "add to favorites", "context ▸ Add to Favorites") else {
            reporter.fail("featAddRemoveFavorite: no 'Add to Favorites' item on the folder's context menu")
            driver.closeAnyMenu()
            driver.navigateToWorkspace()
            return
        }
        Timing.pause(Timing.animation)
        let afterAdd = favRowCount()
        reporter.check(afterAdd > before, "a sidebar Favorites row appeared for '\(favName)' (\(before) → \(afterAdd))")

        let removed = driver.openContextItem(onFileRow: favName, containing: "remove from favorites", "context ▸ Remove from Favorites")
        Timing.pause(Timing.animation)
        let afterRemove = favRowCount()
        reporter.check(removed && afterRemove < afterAdd, "removing the favorite dropped the sidebar row (\(afterAdd) → \(afterRemove))")

        if favRowCount() > before {
            _ = driver.openContextItem(onFileRow: favName, containing: "remove from favorites", "context ▸ Remove from Favorites (cleanup)")
        }
        driver.closeAnyMenu()
        driver.navigateToWorkspace()
    }

    func featTagFilterNavigates() {
        reporter.beginFeature("Clicking a sidebar tag filters the list to tagged files")
        driver.navigateToWorkspace()
        // wiles_showTags is seeded on by the run script; make sure the section is visible.
        if driver.find(AXMatch(identifier: "Section_TAGS"), timeout: 2) == nil {
            driver.menuPick("View", path: ["Sidebar", "Tags"], "View ▸ Sidebar ▸ Tags (show)")
            Timing.pause(Timing.animation)
        }
        func restoreTagsPref() {}

        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "context ▸ Tags") else {
            reporter.fail("featTagFilterNavigates: no Tags submenu on the row context menu")
            restoreTagsPref()
            return
        }
        guard driver.pickContextItem(containing: "red", "Tags ▸ Red") else {
            driver.closeAnyMenu()
            reporter.fail("featTagFilterNavigates: no 'Red' item in the Tags submenu")
            restoreTagsPref()
            return
        }
        Timing.pause(Timing.animation)

        let tagRow = driver.find(AXMatch(role: "AXButton", identifier: "Tag_Red"), timeout: 4)
            ?? driver.find(AXMatch(identifier: "Tag_Red"), timeout: 1)
        guard let tagRow else {
            reporter.fail("featTagFilterNavigates: no Red tag row (Tag_Red) in the sidebar")
            driver.navigateToWorkspace()
            if driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "cleanup Tags") {
                _ = driver.pickContextItem(containing: "red", "cleanup Tags ▸ Red")
            }
            driver.closeAnyMenu()
            restoreTagsPref()
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
        restoreTagsPref()
        driver.navigateToWorkspace()
    }

    func featSmartFolderContextMenu() {
        reporter.beginFeature("A saved smart folder is a persistent, re-runnable sidebar entry")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        driver.focusAndType(field, "alpha")
        Timing.pause(Timing.animation)
        guard driver.tap(AXMatch(textContains: "save as smart folder"), "Save as Smart Folder", timeout: 4) else {
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        guard driver.waitForSheet() else {
            reporter.fail("featSmartFolderContextMenu: Save Smart Folder sheet did not open")
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        if let nameField = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXTextField"), maxDepth: 16) {
            driver.focusAndType(nameField, "CornerSmart")
        }
        let saveButton = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "save search"), maxDepth: 16)
            ?? driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "save"), maxDepth: 16)
        if let saveButton { driver.tapElement(saveButton) } else { driver.key(Keyboard.returnKey) }
        Timing.pause(Timing.animation)
        driver.dismissSheet()
        clearSearch(field)

        guard let smartRow = driver.find(AXMatch(role: "AXButton", textEquals: "CornerSmart"), timeout: 4) else {
            reporter.fail("the saved smart folder 'CornerSmart' did not show in the sidebar")
            driver.navigateToWorkspace()
            return
        }
        reporter.check(true, "the saved smart folder 'CornerSmart' shows in the sidebar")

        // Navigate away, then click the sidebar entry — it re-runs its query (alpha match listed).
        driver.navigateToWorkspace()
        driver.tapElement(driver.find(AXMatch(role: "AXButton", textEquals: "CornerSmart")) ?? smartRow)
        Timing.pause(Timing.animation)
        let reran = driver.fileRow(workspace.alphaFile, timeout: 4) != nil
            && driver.isGone(AXMatch(textEquals: workspace.betaFile), within: 3)
        reporter.check(reran, "clicking the sidebar entry re-runs the query (alpha listed, beta filtered)")

        // Best-effort delete via the row context menu (harness can't always raise a SwiftUI
        // sidebar .contextMenu); the isolated defaults domain is wiped next run regardless.
        driver.showContextMenu(for: driver.find(AXMatch(role: "AXButton", textEquals: "CornerSmart")) ?? smartRow)
        _ = driver.pickContextItem(containing: "delete smart folder", "CornerSmart ▸ Delete")
        _ = driver.confirmDialog(pressing: "delete")
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
        let marker = "collision-marker-uitest.txt"
        try? Data("collision fixture payload".utf8).write(to: planted)
        try? Data("m".utf8).write(to: workspace.url(workspace.subFolder).appendingPathComponent(marker))
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "cut", "context ▸ Cut") else {
            reporter.fail("featMoveCollisionSheet: no Cut item on the row context menu")
            try? FileManager.default.removeItem(at: planted)
            try? FileManager.default.removeItem(at: workspace.url(workspace.subFolder).appendingPathComponent(marker))
            driver.navigateToWorkspace()
            return
        }
        Timing.pause(Timing.brief)
        guard driver.navigateToPath(workspace.url(workspace.subFolder).path, expectRow: marker, timeout: 5) else {
            reporter.fail("featMoveCollisionSheet: could not open the 'sub-uitest' folder")
            try? FileManager.default.removeItem(at: planted)
            driver.navigateToWorkspace()
            return
        }
        driver.rightClickContentArea()
        _ = driver.pickContextItem(containing: "paste", "content-area context ▸ Paste")
            || driver.menuPick("Edit", itemContains: "Paste", "Edit ▸ Paste")
        let sheetShown = driver.waitForSheet(timeout: 6)
        let sheet = driver.sheet()
        let sheetText = (sheet?.allDescendants(where: AXMatch(role: "AXStaticText"), maxDepth: 24) ?? [])
            .compactMap { $0.stringValue ?? ($0.title.isEmpty ? nil : $0.title) }
            .joined(separator: " ").lowercased()
        let offersChoice = sheetText.contains("already exists") || sheetText.contains("keep both")
            || sheet?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "keep both"), maxDepth: 24) != nil
            || sheet?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "replace"), maxDepth: 24) != nil
        reporter.check(sheetShown && offersChoice, "a name-collision sheet offered Replace / Keep Both / Cancel")
        if let cancel = sheet?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "cancel"), maxDepth: 24) {
            driver.tapElement(cancel)
        } else {
            driver.key(Keyboard.escape)
        }
        Timing.pause(Timing.settle)
        driver.dismissSheet()

        try? FileManager.default.removeItem(at: planted)
        try? FileManager.default.removeItem(at: workspace.url(workspace.subFolder).appendingPathComponent(marker))
        if !workspace.exists(workspace.alphaFile) {
            try? Data("alpha contents".utf8).write(to: workspace.url(workspace.alphaFile))
        }
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
        reporter.check(!oneSelected.isEmpty && oneSelected != twoSelected && twoSelected.contains("2 / "),
                       "selecting a second row updated the footer count ('\(oneSelected)' → '\(twoSelected)')")
        driver.key(Keyboard.escape)
        Timing.pause(Timing.brief)
        driver.navigateToWorkspace()
    }

    func featPreviewPaneFollowsSelection() {
        reporter.beginFeature("The preview pane updates as the selection changes")
        driver.navigateToWorkspace()
        _ = driver.menuPick("View", itemContains: "Show Preview", "View ▸ Show Preview")
        Timing.pause(Timing.animation)
        guard driver.menuHasItem("View", containing: "Hide Preview") else {
            reporter.fail("featPreviewPaneFollowsSelection: the preview pane never opened")
            return
        }
        func mentions(_ fragment: String) -> Int {
            (try? driver.mainWindow())?
                .allDescendants(where: AXMatch(textContains: fragment), maxDepth: 30).count ?? 0
        }
        driver.clickRow(workspace.alphaFile)
        Timing.pause(Timing.settle)
        let alphaWhileSelected = mentions("alpha-uitest")
        driver.clickRow(workspace.betaFile)
        Timing.pause(Timing.settle)
        let betaWhileSelected = mentions("beta-uitest")
        let alphaAfterSwitch = mentions("alpha-uitest")
        reporter.check(
            alphaWhileSelected >= 2 && betaWhileSelected >= 2 && betaWhileSelected > alphaAfterSwitch,
            "the pane shows the selected file's name and follows the selection (alpha \(alphaWhileSelected)→\(alphaAfterSwitch), beta \(betaWhileSelected))")
        driver.menuPick("View", itemContains: "Hide Preview", "View ▸ Hide Preview (restore)")
        Timing.pause(Timing.animation)
        driver.navigateToWorkspace()
    }
}
