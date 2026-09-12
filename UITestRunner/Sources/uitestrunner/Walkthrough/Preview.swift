import Foundation

extension PlanWalkthrough {
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
}
