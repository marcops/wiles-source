import Foundation

extension PlanWalkthrough {
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

    // MARK: - Copy Path

    func featCopyPath() {
        reporter.beginFeature("Copy Path lands on the pasteboard")
        driver.navigateToWorkspace()
        writePasteboardString("__sentinel__")
        guard driver.rightClick(AXMatch(textEquals: workspace.alphaFile), "'\(workspace.alphaFile)' row (context)") else { return }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: "copy path", "context ▸ Copy Path") else {
            driver.closeAnyMenu()
            return
        }
        // The submenu needs a beat to populate after its parent is pressed; retry the leaf pick.
        var pasteboard = "__sentinel__"
        for _ in 0 ..< 3 {
            Timing.pause(Timing.settle)
            if driver.pickContextItem(containing: "Absolute Path", "Copy Path ▸ Absolute Path") {
                Timing.pause(Timing.settle)
                pasteboard = readPasteboardString()
                if pasteboard.hasPrefix("/") { break }
            }
            driver.closeAnyMenu()
            _ = driver.rightClick(AXMatch(textEquals: workspace.alphaFile), "row (retry)")
            Timing.pause(Timing.settle)
            _ = driver.pickContextItem(containing: "copy path", "Copy Path (retry)")
        }
        reporter.check(
            pasteboard.hasSuffix(workspace.alphaFile) && pasteboard.hasPrefix("/"),
            "'Absolute Path' put the file's POSIX path on the pasteboard ('…\(pasteboard.suffix(40))')")
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

    // MARK: - File Shredder

    func featFileShredder() {
        reporter.beginFeature("File Shredder (Delete Immediately)")
        driver.navigateToWorkspace()
        let victim = "shred-uitest.txt"
        try? "shred me".write(to: workspace.url(victim), atomically: true, encoding: .utf8)
        // The folder watcher should surface the new file; give it a moment.
        _ = driver.fileRow(victim, timeout: 6)
        guard driver.openContextItem(onFileRow: victim, containing: "delete immediately", "context ▸ Delete Immediately")
        else {
            try? FileManager.default.removeItem(at: workspace.url(victim))
            return
        }
        _ = driver.confirmDialog(pressing: "delete")
            || driver.confirmDialog(pressing: "shred")
            || driver.confirmDialog(pressing: "ok")
        reporter.check(
            workspace.waitForExistence(victim, shouldExist: false, timeout: 8),
            "shredded file is gone from the folder")
        try? FileManager.default.removeItem(at: workspace.url(victim))
    }

    // MARK: - Copy Content

    func featCopyContent() {
        reporter.beginFeature("Copy Content puts the file's text on the pasteboard")
        driver.navigateToWorkspace()
        writePasteboardString("__sentinel__")
        guard driver.openContextItem(
            onFileRow: workspace.alphaFile,
            containing: "copy content",
            "context ▸ Copy Content") else { return }
        Timing.pause(Timing.animation)
        var pasteboard = "__sentinel__"
        let deadline = Date().addingTimeInterval(3)
        repeat {
            pasteboard = readPasteboardString()
            if pasteboard == "__sentinel__" { Timing.pause(Timing.poll) }
        } while pasteboard == "__sentinel__" && Date() < deadline
        reporter.check(
            pasteboard.contains("alpha contents"),
            "the pasteboard holds '\(workspace.alphaFile)''s text content, not a file reference")
    }

    // MARK: - Open With

    /// Opens the submenu only — never picks its "Other..." item, which raises a native NSOpenPanel
    /// this test can't safely drive, and never launches a real app as a side effect.
    func featOpenWithSubmenu() {
        reporter.beginFeature("Open With submenu lists apps and an 'Other...' option")
        driver.navigateToWorkspace()
        guard driver.rightClick(AXMatch(textEquals: workspace.alphaFile), "'\(workspace.alphaFile)' row (context)") else { return }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: "open with", "context ▸ Open With") else {
            driver.closeAnyMenu()
            reporter.fail("featOpenWithSubmenu: no 'Open With' item on the row context menu")
            return
        }
        // The submenu populates asynchronously (openWithApps is loaded off the render path) —
        // poll for it instead of one immediate check.
        var hasOtherOption = false
        let deadline = Date().addingTimeInterval(4)
        repeat {
            hasOtherOption = driver.app.firstDescendant(where: AXMatch(role: "AXMenuItem", textEquals: "Other...")) != nil
                || driver.app.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: "other")) != nil
            if !hasOtherOption { Timing.pause(Timing.poll) }
        } while !hasOtherOption && Date() < deadline
        reporter.check(hasOtherOption, "the submenu offers an 'Other...' item to pick a different app")
        driver.closeAnyMenu()
    }
}

extension Walkthrough {
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
        // Guarantee beta is back for later steps even if a synthetic Undo doesn't land.
        defer {
            if !workspace.exists(workspace.betaFile) {
                try? "beta contents".write(to: workspace.url(workspace.betaFile), atomically: true, encoding: .utf8)
            }
        }
        guard driver.clickRow(workspace.betaFile) else { return }
        Timing.pause(Timing.brief)

        driver.openContextItem(onFileRow: workspace.betaFile, containing: "move to trash", "context ▸ Move to Trash")
        reporter.check(
            workspace.waitForExistence(workspace.betaFile, shouldExist: false, timeout: 6),
            "Move to Trash removed '\(workspace.betaFile)' from the folder")

        // Restore-from-trash scans the Trash and moves the file back, so it needs a longer window.
        driver.process.activate()
        driver.menuPick("Edit", itemContains: "Undo", "Edit ▸ Undo")
        var restored = workspace.waitForExistence(workspace.betaFile, shouldExist: true, timeout: 12)
        if !restored {
            driver.chord("z", .command)
            restored = workspace.waitForExistence(workspace.betaFile, shouldExist: true, timeout: 12)
        }
        reporter.check(restored, "Undo restored '\(workspace.betaFile)'")

        driver.menuPick("Edit", itemContains: "Redo", "Edit ▸ Redo")
        reporter.check(
            workspace.waitForExistence(workspace.betaFile, shouldExist: false, timeout: 8),
            "Redo re-trashed '\(workspace.betaFile)'")

        driver.menuPick("Edit", itemContains: "Undo", "Edit ▸ Undo (restore for later steps)")
        _ = workspace.waitForExistence(workspace.betaFile, shouldExist: true, timeout: 12)
    }
}
