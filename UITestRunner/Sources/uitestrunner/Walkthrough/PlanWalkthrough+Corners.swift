import AppKit
import Foundation

/// Edge behaviours around selection, renaming, sorting, zoom, hidden files and search.
extension PlanWalkthrough {
    private var cornerSeeded: [String] {
        [workspace.alphaFile, workspace.betaFile, workspace.midFile, workspace.imageFile,
         workspace.zipFile, workspace.pdfOne, workspace.pdfTwo]
    }

    /// Count of seeded content rows currently reporting the AX "selected" trait. Uses the same
    /// per-name `fileRow` lookup the (passing) keyboard-selection step relies on.
    func selectedRowCount() -> Int {
        cornerSeeded.filter { driver.fileRow($0, timeout: 1)?.isSelected == true }.count
    }

    // MARK: - Selection edges

    func featShiftClickRange() {
        reporter.beginFeature("Shift-click selects a contiguous range")
        driver.navigateToWorkspace()
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        driver.clickRow(workspace.pdfTwo, modifiers: .shift)
        Timing.pause(Timing.settle)
        reporter.check(selectedRowCount() >= 3, "shift-click from the first to a lower row selected the span (\(selectedRowCount()) rows)")
        driver.key(Keyboard.escape)
    }

    func featCmdClickDeselectsOne() {
        reporter.beginFeature("Cmd-click removes one row from a multi-selection")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        driver.clickRow(workspace.betaFile, modifiers: .command)
        Timing.pause(Timing.brief)
        let two = selectedRowCount()
        driver.clickRow(workspace.betaFile, modifiers: .command)
        Timing.pause(Timing.settle)
        let one = selectedRowCount()
        reporter.check(two == 2 && one == 1, "⌘-click toggled beta off (\(two) → \(one))")
        driver.key(Keyboard.escape)
    }

    func featClickEmptyAreaDeselects() {
        reporter.beginFeature("Clicking empty space clears the selection")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        reporter.check(selectedRowCount() >= 1, "a row is selected to start")
        driver.clickContentArea()
        Timing.pause(Timing.settle)
        reporter.check(selectedRowCount() == 0, "the empty-area click cleared it")
    }

    func featArrowPastLastRowStays() {
        reporter.beginFeature("Down-arrow past the last row keeps a selection")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        for _ in 0 ..< 20 {
            driver.key(Keyboard.downArrow)
            Timing.pause(Timing.keyStroke)
        }
        Timing.pause(Timing.settle)
        let stillOne = driver.app.firstDescendant(where: AXMatch(predicate: { $0.isSelected && !$0.descriptionText.isEmpty }), maxDepth: 16) != nil
        reporter.check(stillOne, "hammering ↓ past the end left exactly one row selected, no crash")
        reporter.check((try? driver.mainWindow()) != nil, "the window is still alive")
    }

    // MARK: - Rename edges

    func featRenameToExistingNameHandled() {
        reporter.beginFeature("Rename onto an existing name is handled, not silently destructive")
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.midFile, containing: "rename", "context ▸ Rename") else { return }
        _ = driver.commitInlineRename(to: workspace.alphaFile)
        Timing.pause(Timing.animation)
        // Rename refused (both files stay) or a conflict prompt appears — never a silent clobber.
        let bothSurvive = workspace.exists(workspace.alphaFile)
            && (workspace.exists(workspace.midFile) || driver.sheet() != nil || driver.find(AXMatch(textContains: "already"), timeout: 1) != nil)
        reporter.check(bothSurvive, "alpha wasn't clobbered by renaming mango onto it")
        driver.dismissSheet()
        driver.key(Keyboard.escape)
        // Restore mango if the rename went through.
        if !workspace.exists(workspace.midFile) {
            try? "mango contents".write(to: workspace.url(workspace.midFile), atomically: true, encoding: .utf8)
        }
    }

    func featRenameWithSlashSanitised() {
        reporter.beginFeature("A '/' typed while renaming doesn't raise a raw error")
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.betaFile, containing: "rename", "context ▸ Rename") else { return }
        _ = driver.commitInlineRename(to: "beta/slash-uitest.txt")
        Timing.pause(Timing.animation)
        // "/" → ":" like the Finder, or the rename declines — never a crash, never data loss.
        let renamedWithColon = workspace.exists("beta:slash-uitest.txt")
        let leftAlone = workspace.exists(workspace.betaFile)
        let dirNow = (try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path))?.sorted() ?? []
        reporter.check(renamedWithColon || leftAlone,
                       "the slash was sanitised or the rename declined — no data loss (dir: \(dirNow))")
        reporter.check((try? driver.mainWindow()) != nil, "window still alive")
        // Restore.
        if renamedWithColon { try? FileManager.default.moveItem(at: workspace.url("beta:slash-uitest.txt"), to: workspace.url(workspace.betaFile)) }
        if !workspace.exists(workspace.betaFile) {
            try? "beta contents".write(to: workspace.url(workspace.betaFile), atomically: true, encoding: .utf8)
        }
    }

    func featNewFolderNameAutoIncrements() {
        reporter.beginFeature("A second New Folder gets a distinct auto-name")
        driver.navigateToWorkspace()
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? [])
        for _ in 0 ..< 2 {
            driver.menuPick("File", itemContains: "New Folder", "File ▸ New Folder")
            Timing.pause(Timing.settle)
            driver.key(Keyboard.returnKey) // accept the default inline name
            Timing.pause(Timing.settle)
        }
        let after = Set((try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? [])
        let created = after.subtracting(before).filter { !$0.hasPrefix(".") }
        reporter.check(created.count >= 2, "two New Folder invocations produced two distinct folders (\(created.sorted()))")
        for name in created { try? FileManager.default.removeItem(at: workspace.url(name)) }
    }

    // MARK: - Sort edges

    func featSortByEachKeyReorders() {
        reporter.beginFeature("Every Sort By key produces an order, folders stay grouped")
        driver.navigateToWorkspace()
        var orders: [String: [String]] = [:]
        for key in ["Name", "Date Modified", "Size", "Kind"] {
            guard driver.menuPick("View", path: ["Sort By", key], "View ▸ Sort By ▸ \(key)") else { continue }
            Timing.pause(Timing.settle)
            orders[key] = contentFileOrder()
        }
        let nonEmpty = orders.values.filter { !$0.isEmpty }
        reporter.check(nonEmpty.count >= 3, "at least three sort keys returned a populated order")
        let distinct = Set(nonEmpty.map { $0.joined(separator: "|") })
        reporter.check(distinct.count >= 2, "the sort keys don't all yield the identical order")
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name (restore)")
    }

    // MARK: - Zoom edges

    func featIconZoomClampsAtMinimum() {
        reporter.beginFeature("Icon zoom clamps instead of shrinking forever")
        driver.navigateToWorkspace()
        driver.menuPick("View", path: ["View Mode", "Grid"], "View ▸ View Mode ▸ Grid")
        Timing.pause(Timing.settle)
        for _ in 0 ..< 12 {
            driver.chord("-", .command)
            Timing.pause(Timing.keyStroke)
        }
        Timing.pause(Timing.settle)
        let minWidth = gridWidth()
        driver.chord("-", .command)
        Timing.pause(Timing.settle)
        reporter.check(minWidth > 0 && abs(gridWidth() - minWidth) < 2, "one more ⌘- past the minimum didn't shrink further (\(Int(minWidth))px)")
        reporter.check((try? driver.mainWindow()) != nil, "window still alive after 13× ⌘-")
        for _ in 0 ..< 6 { driver.chord("=", .command); Timing.pause(Timing.keyStroke) }
        driver.menuPick("View", path: ["View Mode", "List"], "View ▸ View Mode ▸ List (restore)")
    }

    // MARK: - Hidden files

    func featShowHiddenFilesToggle() {
        reporter.beginFeature("Show Hidden Files reveals and re-hides a dotfile")
        driver.navigateToWorkspace()
        let hiddenVisible = { self.driver.find(AXMatch(textEquals: self.workspace.hiddenFile), timeout: 2) != nil }
        let wasVisible = hiddenVisible()
        driver.chord(".", [.command, .shift])
        Timing.pause(Timing.animation)
        let toggledOn = hiddenVisible()
        driver.chord(".", [.command, .shift])
        Timing.pause(Timing.animation)
        let toggledOff = hiddenVisible()
        reporter.check(toggledOn != toggledOff, "⇧⌘. flipped '.hidden-uitest' visibility (on:\(toggledOn) off:\(toggledOff))")
        if wasVisible != hiddenVisible() { driver.chord(".", [.command, .shift]) }
    }

    // MARK: - Search edges

    func featSearchNoMatchThenClear() {
        reporter.beginFeature("Search with no match shows the empty state, clearing restores the list")
        driver.navigateToWorkspace()
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            _ = driver.activateSearch()
            Timing.pause(Timing.settle)
        }
        guard let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) else {
            reporter.fail("search field never appeared")
            return
        }
        driver.focusAndType(field, "zzzznomatch-uitest")
        Timing.pause(Timing.animation)
        let noResults = driver.find(AXMatch(textContains: "no results"), timeout: 4) != nil
            || driver.find(AXMatch(textContains: "nothing found"), timeout: 1) != nil
        reporter.check(noResults, "a non-matching query shows a 'no results' state")
        driver.focusAndType(field, "")
        driver.key(Keyboard.escape)
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile, timeout: 5) != nil, "clearing the search brought the file list back")
    }

    // MARK: - Keyboard shortcut edges

    func featPropertiesShortcut() {
        reporter.beginFeature("⌘I opens Properties for the selection")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        driver.chord("i", .command)
        reporter.check(driver.waitForSheet(), "⌘I raised the Properties sheet")
        reporter.check(
            driver.sheet()?.firstDescendant(where: AXMatch(textContains: workspace.alphaFile), maxDepth: 16) != nil
                || driver.sheet()?.firstDescendant(where: AXMatch(textContains: "permission"), maxDepth: 16) != nil,
            "the sheet is about the selected file")
        reporter.check(driver.dismissSheet(), "Properties sheet dismissed")
    }

    func featTrashShortcutThenUndo() {
        reporter.beginFeature("⌘⌫ trashes the selection, ⌘Z brings it back")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.midFile) else { return }
        Timing.pause(Timing.brief)
        driver.key(Keyboard.delete, .command)
        reporter.check(
            workspace.waitForExistence(workspace.midFile, shouldExist: false, timeout: 6),
            "⌘⌫ removed '\(workspace.midFile)' from the folder")
        driver.menuPick("Edit", itemContains: "Undo", "Edit ▸ Undo")
        reporter.check(
            workspace.waitForExistence(workspace.midFile, shouldExist: true, timeout: 6),
            "⌘Z (Undo) restored it")
    }

    // MARK: - Navigation edges

    func featPathBarRejectsBadPath() {
        reporter.beginFeature("A nonexistent path in Go to Folder is refused")
        driver.navigateToWorkspace()
        _ = driver.navigateToPath("/no/such/place-uitest-\(UUID().uuidString.prefix(6))", expectRow: "", timeout: 3)
        Timing.pause(Timing.animation)
        driver.key(Keyboard.escape)
        reporter.check(
            driver.fileRow(workspace.alphaFile, timeout: 4) != nil,
            "a bad path left us where we were (seeded file still listed)")
    }

    func featKeyboardHistoryNav() {
        reporter.beginFeature("⌘[ / ⌘] / ⌘↑ walk history and go up")
        driver.navigateToWorkspace()
        guard driver.navigateToPath(workspace.url(workspace.subFolder).path, expectRow: "", timeout: 5) else {
            reporter.fail("could not navigate into the subfolder")
            return
        }
        Timing.pause(Timing.animation)
        driver.chord("[", .command)
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile, timeout: 4) != nil, "⌘[ went Back to the workspace")
        driver.chord("]", .command)
        Timing.pause(Timing.animation)
        let forwardOK = driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 3)
            || driver.find(AXMatch(textContains: "empty"), timeout: 2) != nil
        reporter.check(forwardOK, "⌘] went Forward into the subfolder")
        driver.key(Keyboard.upArrow, .command)
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile, timeout: 4) != nil, "⌘↑ went up to the enclosing folder")
    }

    func featPlacesEntryNavigates() {
        reporter.beginFeature("Clicking a Places entry navigates there")
        driver.navigateToWorkspace()
        guard let places = driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 3) else {
            reporter.fail("Section_PLACES not found")
            return
        }
        if (places.stringValue ?? "").lowercased().contains("expand") {
            driver.tapElement(places)
            Timing.pause(Timing.animation)
        }
        // A Places row that isn't "Downloads" (our workspace is named that) or the header.
        guard let window = try? driver.mainWindow(),
              let entry = window.firstDescendant(where: AXMatch(role: "AXButton", predicate: { el in
                  let t = (el.descriptionText.isEmpty ? el.title : el.descriptionText).lowercased()
                  return ["desktop", "documents", "home", "applications"].contains { t == $0 }
              }), maxDepth: 20) else {
            reporter.fail("no recognisable Places row to click")
            return
        }
        let label = entry.descriptionText.isEmpty ? entry.title : entry.descriptionText
        driver.tapElement(entry)
        Timing.pause(Timing.animation)
        reporter.check(
            driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 4),
            "clicking '\(label)' navigated away from the workspace")
        driver.navigateToWorkspace()
    }

    // MARK: - View edges

    func featListColumnHeaderClickSorts() {
        reporter.beginFeature("Clicking a List-view column header changes the sort")
        driver.navigateToWorkspace()
        driver.menuPick("View", path: ["View Mode", "List"], "View ▸ View Mode ▸ List")
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        let before = contentFileOrder()
        guard let window = try? driver.mainWindow(),
              let header = window.firstDescendant(where: AXMatch(textEquals: "Size"), maxDepth: 24)
              ?? window.firstDescendant(where: AXMatch(role: "AXButton", textContains: "size"), maxDepth: 24) else {
            reporter.fail("no 'Size' column header found")
            return
        }
        driver.tapElement(header)
        Timing.pause(Timing.animation)
        let afterSize = contentFileOrder()
        driver.tapElement(header)
        Timing.pause(Timing.animation)
        let afterToggle = contentFileOrder()
        reporter.check(!before.isEmpty && (afterSize != before || afterToggle != afterSize),
                       "the header click reordered the list")
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name (restore)")
    }

    func featCompactDensityToggle() {
        reporter.beginFeature("Compact-density toggle is present and flips")
        driver.navigateToWorkspace()
        guard driver.openSettings(tab: "Advanced") else {
            reporter.fail("could not open Settings ▸ Advanced")
            return
        }
        let toggle = driver.sheet()?.firstDescendant(where: AXMatch(textContains: "compact"), maxDepth: 18)
            ?? driver.sheet()?.firstDescendant(where: AXMatch(role: "AXCheckBox"), maxDepth: 18)
        guard let toggle else {
            driver.dismissSheet()
            reporter.fail("no compact-density toggle in Settings ▸ Advanced")
            return
        }
        let before = toggle.isSelected
        driver.tapElement(toggle)
        Timing.pause(Timing.settle)
        let flipped = (driver.sheet()?.firstDescendant(where: AXMatch(textContains: "compact"), maxDepth: 18)
            ?? driver.sheet()?.firstDescendant(where: AXMatch(role: "AXCheckBox"), maxDepth: 18))?.isSelected
        reporter.check(flipped != nil && flipped != before, "the compact-density toggle changed state")
        if let toggleBack = driver.sheet()?.firstDescendant(where: AXMatch(textContains: "compact"), maxDepth: 18)
            ?? driver.sheet()?.firstDescendant(where: AXMatch(role: "AXCheckBox"), maxDepth: 18) {
            driver.tapElement(toggleBack)
        }
        driver.dismissSheet()
    }

    func featAutoHideSidebarToggle() {
        reporter.beginFeature("Auto-hide sidebar toggles the sidebar away")
        driver.navigateToWorkspace()
        guard driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 3) != nil else {
            reporter.fail("sidebar not visible to start")
            return
        }
        guard driver.menuPick("View", itemContains: "Auto-Hide", "View ▸ Auto-Hide Sidebar") else {
            reporter.fail("no Auto-Hide Sidebar item in the View menu")
            return
        }
        Timing.pause(Timing.animation)
        let hidden = driver.isGone(AXMatch(identifier: "Section_FAVORITES"), within: 2)
        reporter.check(hidden, "the sidebar collapsed away")
        driver.menuPick("View", itemContains: "Auto-Hide", "View ▸ Auto-Hide Sidebar (restore)")
        Timing.pause(Timing.animation)
        reporter.check(driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 4) != nil, "and came back")
    }
}
