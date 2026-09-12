import Foundation

extension PlanWalkthrough {
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

    /// Finder-style click-to-rename in grid view: click a selected folder's name and the inline
    /// field opens over the card. ~3s later the card's name-reveal timer
    /// (`AsyncDelayTokens.nameRevealDelay`) fires `revealingFullNameURL`, and `FileGridView`'s
    /// `revealFieldOverlay` — which has no guard against an active rename — draws the full-name
    /// pill on top of the rename field, hiding it. The edit still commits blind, but the user can't
    /// see what they're typing. List view has no such overlay. Asserts no reveal pill is drawn
    /// while a grid rename is open.
    func featGridRenameNotCoveredByNameReveal() {
        reporter.beginFeature("Grid rename field isn't hidden by the 3s name-reveal pill")
        driver.navigateToWorkspace()
        defer {
            driver.key(Keyboard.escape)
            driver.hover(AXMatch(identifier: "View Mode"), "view mode (restore)")
            Timing.pause(Timing.settle)
            driver.tap(AXMatch(identifier: "ViewModeList"), "list view (restore)")
        }

        driver.hover(AXMatch(identifier: "View Mode"), "view mode")
        Timing.pause(Timing.settle)
        guard driver.tap(AXMatch(identifier: "ViewModeGrid"), "switch to grid view") else { return }
        Timing.pause(Timing.animation)

        // Finder-style click-to-rename: click the folder card (selects), then click again once it's
        // the sole selection to open the inline field ~400ms later.
        guard driver.clickRow(workspace.subFolder) else { return }
        Timing.pause(0.8)
        driver.clickRow(workspace.subFolder)

        guard driver.find(AXMatch(identifier: "InlineRenameField"), timeout: 3) != nil else {
            reporter.fail("click-to-rename never opened the inline field in grid view")
            return
        }
        reporter.pass("click-to-rename opened the inline field in grid view")

        // Wait past the 3s name-reveal timer, touching nothing.
        Timing.pause(4.5)

        // The reveal pill renders the folder name as plain static text on an accent background,
        // stacked over the rename field. While renaming, it must not exist.
        let window = try? driver.mainWindow()
        let revealPill = window?
            .allDescendants(where: AXMatch(role: "AXStaticText", textContains: workspace.subFolder), maxDepth: 22)
            .first { !$0.frame.isEmpty }
        reporter.check(
            revealPill == nil,
            "no full-name reveal pill is drawn over the open grid rename field (found: \(revealPill?.stringValue ?? "none"))")
        reporter.check(
            driver.find(AXMatch(identifier: "InlineRenameField"), timeout: 1) != nil,
            "rename field is still open 4.5s after entering it")
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

    func featRenameMenuItem() {
        reporter.beginFeature("File ▸ Rename… menu item")
        driver.navigateToWorkspace()
        // Checked before selecting anything: `menuHasItem`/`menuPick` open the menu via a leading
        // Escape (to dismiss any stale menu first), which is also this app's "clear selection"
        // shortcut — sending it after selecting a row would wipe the very selection being tested.
        // ⌘R below exercises the same File ▸ Rename… action without that side effect.
        reporter.check(driver.menuHasItem("File", containing: "Rename"), "File menu lists a Rename item")

        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        driver.chord("r", .command)
        reporter.check(
            driver.find(AXMatch(identifier: "InlineRenameField"), timeout: 3) != nil,
            "⌘R (File ▸ Rename…) on a single selection opens the inline rename field")
        driver.key(Keyboard.escape)
        Timing.pause(Timing.settle)

        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        guard driver.clickRow(workspace.betaFile, modifiers: .command) else { return }
        Timing.pause(Timing.settle)
        driver.chord("r", .command)
        reporter.check(driver.waitForSheet(), "⌘R (File ▸ Rename…) on a 2+ selection opens the Batch Rename sheet")
        reporter.check(driver.dismissSheet(), "Batch Rename sheet dismissed")
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

    // MARK: - Batch Rename result correctness

    /// featBatchRename (Walkthrough) only asserts the sheet opens and shows rename-mode controls;
    /// this drives Find & Replace end to end and checks the files actually got renamed on disk.
    func featBatchRenameAppliesFindReplace() {
        reporter.beginFeature("Batch Rename Find & Replace actually renames the files")
        driver.navigateToWorkspace()
        let nameA = "batchren-a-uitest.txt"
        let nameB = "batchren-b-uitest.txt"
        let renamedA = "batchfix-a-uitest.txt"
        let renamedB = "batchfix-b-uitest.txt"
        try? "a".write(to: workspace.url(nameA), atomically: true, encoding: .utf8)
        try? "b".write(to: workspace.url(nameB), atomically: true, encoding: .utf8)
        defer {
            for name in [nameA, nameB, renamedA, renamedB] {
                try? FileManager.default.removeItem(at: workspace.url(name))
            }
        }
        _ = driver.fileRow(nameA, timeout: 6)

        guard driver.clickRow(nameA) else { return }
        Timing.pause(Timing.brief)
        guard driver.clickRow(nameB, modifiers: .command) else { return }
        Timing.pause(Timing.settle)
        guard driver.rightClick(AXMatch(textEquals: nameA), "'\(nameA)' row (context)", preClick: false) else { return }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: "rename", "context ▸ Rename (multi-select)") else { return }
        guard driver.waitForSheet() else {
            reporter.fail("featBatchRenameAppliesFindReplace: Batch Rename sheet did not open")
            return
        }
        // Default tab is Find & Replace — its two text fields have no unique identifier, so take
        // them by order: the sheet's first two AXTextField descendants.
        let fields = driver.sheet()?.allDescendants(where: AXMatch(role: "AXTextField"), maxDepth: 16) ?? []
        guard fields.count >= 2 else {
            reporter.fail("featBatchRenameAppliesFindReplace: expected 2 text fields, found \(fields.count)")
            driver.dismissSheet()
            return
        }
        guard driver.focusAndType(fields[0], "batchren-"), driver.focusAndType(fields[1], "batchfix-") else {
            reporter.fail("featBatchRenameAppliesFindReplace: could not type into the Find/Replace fields")
            driver.dismissSheet()
            return
        }
        Timing.pause(Timing.settle)
        guard let applyButton = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "apply")) else {
            reporter.fail("featBatchRenameAppliesFindReplace: no Apply button in the sheet")
            driver.dismissSheet()
            return
        }
        driver.tapElement(applyButton)
        reporter.check(
            workspace.waitForExistence(renamedA, shouldExist: true, timeout: 6)
                && workspace.waitForExistence(renamedB, shouldExist: true, timeout: 6)
                && !workspace.exists(nameA) && !workspace.exists(nameB),
            "both files were renamed on disk ('\(nameA)' → '\(renamedA)', '\(nameB)' → '\(renamedB)')")
    }
}

extension Walkthrough {
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
            driver.process.activate()
            guard driver.clickRow(workspace.alphaFile) else { return }
            Timing.pause(Timing.brief)
            switch attempt {
            case 0: driver.clickRow(workspace.betaFile, modifiers: .command)
            case 1: driver.chord("a", .command)
            default: driver.key(Keyboard.downArrow, .shift)
            }
            Timing.pause(Timing.settle)
            guard driver.rightClick(AXMatch(textEquals: workspace.alphaFile), "'\(workspace.alphaFile)' row (context)", preClick: false)
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
}
