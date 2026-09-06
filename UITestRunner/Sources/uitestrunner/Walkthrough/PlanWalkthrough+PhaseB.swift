import Foundation

extension PlanWalkthrough {
    // MARK: - File Properties chmod surface

    func featChmodInProperties() {
        reporter.beginFeature("File Properties — permissions editor")
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "properties", "context ▸ Properties")
        else { return }
        guard driver.waitForSheet() else {
            reporter.fail("Properties sheet did not open")
            return
        }
        if let byText = driver.sheet()?.firstDescendant(where: AXMatch(textContains: "permission")) {
            driver.tapElement(byText)
            Timing.pause(Timing.settle)
        }
        let sheet = driver.sheet()
        let hasPermissionsUI = sheet?.firstDescendant(where: AXMatch(textContains: "permission")) != nil
            || sheet?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "apply")) != nil
            || (sheet?.allDescendants(where: AXMatch(role: "AXCheckBox"), maxDepth: 18).count ?? 0) >= 3
        reporter.check(hasPermissionsUI, "Properties sheet exposes a permissions (chmod) section")
        driver.dismissSheet()
    }

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

    // MARK: - Finder tags

    func featTagAssign() {
        reporter.beginFeature("Assign a Finder tag via context menu")
        driver.navigateToWorkspace()
        guard driver.rightClick(AXMatch(textEquals: workspace.betaFile), "'\(workspace.betaFile)' row (context)") else { return }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: "tags", "context ▸ Tags submenu") else {
            driver.closeAnyMenu()
            return
        }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: "Red", "Tags ▸ Red") else {
            driver.closeAnyMenu()
            return
        }
        Timing.pause(Timing.animation)
        // The macOS tag colour name is localised by the *system* language, so just assert a tag
        // was written (e.g. "Red" / "Vermelho").
        let tags = fileTagNames(workspace.url(workspace.betaFile))
        reporter.check(!tags.isEmpty, "a colour tag was written to the file (\(tags))")
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

    // MARK: - PDF merge

    func featPDFMerge() {
        reporter.beginFeature("Merge multiple PDFs")
        driver.navigateToWorkspace()
        // Sort by name so one-/two-uitest.pdf are adjacent, click the first, then Shift+↓ to
        // extend the selection to the second (arrow-key extension is more reliable than
        // modifier-clicks through synthetic events).
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        driver.clickRow(workspace.pdfOne)
        Timing.pause(Timing.brief)
        driver.key(Keyboard.downArrow, .shift)
        Timing.pause(Timing.settle)
        var haveMergeItem = false
        for _ in 0 ..< 3 {
            driver.rightClick(AXMatch(textEquals: workspace.pdfTwo), "'\(workspace.pdfTwo)' row (context)")
            Timing.pause(Timing.settle)
            if driver.app.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: "merge"), maxDepth: 12) != nil {
                haveMergeItem = true
                break
            }
            driver.closeAnyMenu()
            driver.clickRow(workspace.pdfTwo, modifiers: .command)
            Timing.pause(Timing.settle)
        }
        guard haveMergeItem, driver.pickContextItem(containing: "merge", "context ▸ Merge into Single PDF") else {
            driver.closeAnyMenu()
            reporter.fail("could not get a 2-PDF selection with a 'Merge into Single PDF' item")
            return
        }
        Timing.pause(Timing.animation)
        let mergedAppeared = (try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path))?
            .contains { $0.lowercased().hasSuffix(".pdf") && $0 != workspace.pdfOne && $0 != workspace.pdfTwo } ?? false
        reporter.check(mergedAppeared, "a merged .pdf was written to the folder")
        if let merged = (try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path))?
            .first(where: { $0.lowercased().hasSuffix(".pdf") && $0 != workspace.pdfOne && $0 != workspace.pdfTwo }) {
            try? FileManager.default.removeItem(at: workspace.url(merged))
        }
    }

    // MARK: - Smart folder round trip

    func featSmartFolderRoundTrip() {
        reporter.beginFeature("Smart Folder — save a query and open it")
        driver.navigateToWorkspace()
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            driver.tap(AXMatch(identifier: "magnifyingglass"), "search", timeout: 3)
            Timing.pause(Timing.settle)
        }
        if let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) {
            driver.focusAndType(field, "alpha")
            Timing.pause(Timing.animation)
        }
        guard driver.tap(AXMatch(textContains: "save as smart folder"), "Save as Smart Folder", timeout: 4) else {
            driver.tap(AXMatch(identifier: "magnifyingglass"), "search close", timeout: 3)
            return
        }
        guard driver.waitForSheet() else {
            reporter.fail("Save Smart Folder sheet did not open")
            return
        }
        if let nameField = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXTextField")) {
            driver.focusAndType(nameField, "PlanSmart")
        }
        let saved = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "save"))
            ?? driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "create"))
        if let saved { driver.tapElement(saved) } else { driver.key(Keyboard.returnKey) }
        Timing.pause(Timing.animation)
        driver.dismissSheet()

        driver.tap(AXMatch(identifier: "magnifyingglass"), "search close", timeout: 3)
        Timing.pause(Timing.settle)
        let row = driver.find(AXMatch(role: "AXButton", textEquals: "PlanSmart"), timeout: 4)
        reporter.check(row != nil, "the saved smart folder 'PlanSmart' shows in the sidebar")
        if let row {
            driver.tapElement(row)
            Timing.pause(Timing.animation)
            reporter.check(
                driver.fileRow(workspace.alphaFile, timeout: 4) != nil,
                "opening the smart folder re-runs the query (alpha match listed)")
        }
        driver.navigateToWorkspace()
    }

    // MARK: - HTTP server round trip

    func featHTTPServerRoundTrip() {
        reporter.beginFeature("HTTP Sharing — start, fetch, stop")
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.subFolder, containing: "share folder over wi-fi", "context ▸ Share over Wi-Fi")
        else { return }
        guard driver.waitForSheet() else {
            reporter.fail("HTTP Sharing sheet did not open")
            return
        }
        let startButton = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "start"))
        if let startButton { driver.tapElement(startButton) }
        Timing.pause(Timing.animation)
        let sheetText = (driver.sheet()?.allDescendants(where: AXMatch(role: "AXStaticText"), maxDepth: 12) ?? [])
            .compactMap { $0.stringValue ?? ($0.title.isEmpty ? nil : $0.title) }
            .joined(separator: " ")
        let port = firstPort(in: sheetText)
        if let port {
            let body = httpGet("http://127.0.0.1:\(port)/")
            reporter.check(body != nil, "the shared folder answers on port \(port)")
        } else {
            reporter.check(startButton != nil, "HTTP share sheet exposes a Start control (no port string to probe)")
        }
        if let stop = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "stop")) {
            driver.tapElement(stop)
        }
        Timing.pause(Timing.settle)
        driver.dismissSheet()
    }

    // MARK: - Navigation mode

    func featNavigationModeGnome() {
        reporter.beginFeature("Navigation mode — GNOME Enter-to-open")
        guard driver.openSettings(tab: "General") else { return }
        let switched = driver.selectPickerOption("Windows Mode", popupIndex: 1)
        driver.dismissSheet()
        Timing.pause(Timing.settle)
        guard switched else {
            reporter.fail("could not set shortcut mode to GNOME/Linux")
            return
        }

        driver.navigateToWorkspace()
        let marker = "gnome-open-marker.txt"
        try? "x".write(to: workspace.url(workspace.subFolder).appendingPathComponent(marker), atomically: true, encoding: .utf8)
        driver.clickRow(workspace.subFolder)
        Timing.pause(Timing.brief)
        driver.key(Keyboard.returnKey)
        Timing.pause(Timing.animation)
        reporter.check(
            driver.fileRow(marker, timeout: 5) != nil,
            "Enter opened the folder in GNOME mode")
        try? FileManager.default.removeItem(at: workspace.url(workspace.subFolder).appendingPathComponent(marker))
        driver.menuPick("Go", itemContains: "Enclosing Folder", "Go ▸ Enclosing Folder (back)")
        Timing.pause(Timing.animation)

        // Restore macOS mode.
        if driver.openSettings(tab: "General") {
            driver.selectPickerOption("macOS Mode", popupIndex: 1)
            driver.dismissSheet()
        }
        driver.navigateToWorkspace()
    }

    // MARK: - Preference persistence sweep

    func featPreferencePersistenceSweep() {
        reporter.beginFeature("Preference persistence sweep")
        driver.navigateToWorkspace()

        driver.menuPick("View", path: ["View Mode", "Grid"], "View ▸ View Mode ▸ Grid")
        Timing.pause(Timing.animation)
        driver.menuPick("View", itemContains: "Show Terminal", "View ▸ Show Terminal")
        Timing.pause(Timing.settle)

        let checks: [(String, (String) -> Bool)] = [
            ("wiles_viewMode", { $0.contains("Grid") }),
            ("wiles_appLanguage", { $0.contains("en") }),
            ("wiles_isFavoritesExpanded", { !$0.isEmpty }),
        ]
        for (key, valid) in checks {
            let value = driver.process.readDefault(key) ?? ""
            reporter.check(valid(value), "\(key) persisted ('\(value)')")
        }

        driver.menuPick("View", itemContains: "Hide Terminal", "View ▸ Hide Terminal (restore)")
        driver.menuPick("View", path: ["View Mode", "List"], "View ▸ View Mode ▸ List (restore)")
    }
}
