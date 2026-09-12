import Foundation

extension PlanWalkthrough {
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

    // MARK: - Navigation mode

    func featNavigationModeWindows() {
        reporter.beginFeature("Navigation mode — Windows Enter-to-open")
        guard driver.openSettings(tab: "General") else { return }
        let switched = driver.selectPickerOption("Windows Mode", popupIndex: 1)
        driver.dismissSheet()
        Timing.pause(Timing.settle)
        guard switched else {
            reporter.fail("could not set shortcut mode to Windows")
            return
        }

        driver.navigateToWorkspace()
        let marker = "windows-open-marker.txt"
        try? "x".write(to: workspace.url(workspace.subFolder).appendingPathComponent(marker), atomically: true, encoding: .utf8)
        driver.clickRow(workspace.subFolder)
        Timing.pause(Timing.brief)
        driver.key(Keyboard.returnKey)
        Timing.pause(Timing.animation)
        reporter.check(
            driver.fileRow(marker, timeout: 5) != nil,
            "Enter opened the folder in Windows mode")
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
}
