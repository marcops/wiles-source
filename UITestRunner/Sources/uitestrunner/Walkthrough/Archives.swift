import Foundation

extension PlanWalkthrough {
    // MARK: - Archive extract

    func featArchiveExtract() {
        reporter.beginFeature("Archive — extract a .zip")
        driver.navigateToWorkspace()
        let extractedDir = (workspace.zipFile as NSString).deletingPathExtension
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? [])
        try? FileManager.default.removeItem(at: workspace.url(extractedDir))
        guard driver.openContextItem(onFileRow: workspace.zipFile, containing: "extract archive", "context ▸ Extract Archive")
        else { return }
        var appeared = false
        let deadline = Date().addingTimeInterval(15)
        repeat {
            let now = Set((try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? [])
            if !now.subtracting(before).isEmpty { appeared = true; break }
            Timing.pause(Timing.settle)
        } while Date() < deadline
        reporter.check(appeared, "extracting '\(workspace.zipFile)' created new output in the folder")
        try? FileManager.default.removeItem(at: workspace.url(extractedDir))
    }

    // MARK: - Compress with Password

    func featCompressWithPassword() {
        reporter.beginFeature("Compress with Password — secure-field sheet")
        driver.navigateToWorkspace()
        guard driver.openContextItem(
            onFileRow: workspace.alphaFile,
            containing: "compress with password",
            "context ▸ Compress with Password") else { return }
        guard driver.waitForSheet() else {
            reporter.fail("Compress with Password sheet never opened")
            return
        }
        reporter.check(
            driver.sheet()?.firstDescendant(where: AXMatch(role: "AXTextField"), maxDepth: 16) != nil
                || driver.sheet()?.firstDescendant(where: AXMatch(textContains: "password"), maxDepth: 16) != nil,
            "the sheet exposes a password field")
        reporter.check(driver.dismissSheet(), "Compress with Password sheet dismissed")
    }

    // MARK: - PDF merge

    func featPDFMerge() {
        reporter.beginFeature("Merge multiple PDFs")
        // Isolate the two PDFs in their own folder so the selection can only ever be PDFs.
        // Distinct names so navigateToPath's expectRow check can't false-pass against the
        // identically-named PDFs still sitting in the workspace root.
        let mergeA = "merge-a-uitest.pdf"
        let mergeB = "merge-b-uitest.pdf"
        let pdfDir = workspace.url("pdfs-uitest")
        try? FileManager.default.removeItem(at: pdfDir)
        try? FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true)
        try? FileManager.default.copyItem(at: workspace.url(workspace.pdfOne), to: pdfDir.appendingPathComponent(mergeA))
        try? FileManager.default.copyItem(at: workspace.url(workspace.pdfTwo), to: pdfDir.appendingPathComponent(mergeB))
        guard driver.navigateToPath(pdfDir.path, expectRow: mergeA) else {
            reporter.fail("could not open the isolated PDF folder")
            try? FileManager.default.removeItem(at: pdfDir)
            return
        }
        // Land a 2-row selection then right-click. Synthetic ⌘-click is the reliable extender here;
        // Edit ▸ Select All only reaches the list once it has key focus, so keep a couple of
        // fallbacks and stop as soon as the context menu offers "Merge into Single PDF".
        var haveMergeItem = false
        for attempt in 0 ..< 3 {
            driver.closeAnyMenu()
            driver.clickRow(mergeA)
            Timing.pause(Timing.brief)
            switch attempt {
            case 0:
                driver.clickRow(mergeB, modifiers: .command)
            case 1:
                driver.key(Keyboard.downArrow, .shift)
            default:
                driver.menuPick("Edit", itemContains: "Select All", "Edit ▸ Select All")
            }
            Timing.pause(Timing.settle)
            driver.rightClick(AXMatch(textEquals: mergeB), "'\(mergeB)' row (context)", preClick: false)
            Timing.pause(Timing.settle)
            if driver.app.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: "merge"), maxDepth: 12) != nil {
                haveMergeItem = true
                break
            }
        }
        guard haveMergeItem, driver.pickContextItem(containing: "merge", "context ▸ Merge into Single PDF") else {
            driver.closeAnyMenu()
            reporter.fail("could not get a 2-PDF selection with a 'Merge into Single PDF' item")
            try? FileManager.default.removeItem(at: pdfDir)
            return
        }
        Timing.pause(Timing.animation)
        let mergedAppeared = (try? FileManager.default.contentsOfDirectory(atPath: pdfDir.path))?
            .contains { $0.lowercased().hasSuffix(".pdf") && $0 != mergeA && $0 != mergeB } ?? false
        reporter.check(mergedAppeared, "a merged .pdf was written to the folder")
        try? FileManager.default.removeItem(at: pdfDir)
    }
}

extension Walkthrough {
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
}
