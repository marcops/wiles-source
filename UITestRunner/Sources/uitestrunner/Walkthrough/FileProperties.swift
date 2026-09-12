import Foundation

extension PlanWalkthrough {
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

    // MARK: - Folder Properties (background context menu)

    /// Distinct from featFileProperties: opened via the empty-area context menu, about the
    /// *current folder itself* (SharedBackgroundContextMenu), not a selected file row.
    func featFolderPropertiesFromBackground() {
        reporter.beginFeature("Folder Properties (background context menu)")
        // A genuinely empty, dedicated folder — not the shared workspace root, which by this point
        // in a long chunked pass can hold enough accumulated files that the background right-click's
        // fixed screen point lands on a real row instead of empty space (see featClickEmptyAreaDeselects).
        let emptyDir = workspace.url("folder-props-uitest")
        try? FileManager.default.removeItem(at: emptyDir)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }
        guard driver.navigateToPath(emptyDir.path, expectRow: "") else {
            reporter.fail("featFolderPropertiesFromBackground: could not navigate to the isolated empty folder")
            driver.navigateToWorkspace()
            return
        }
        Timing.pause(Timing.settle)
        guard driver.rightClickContentArea() else {
            reporter.fail("featFolderPropertiesFromBackground: background right-click failed")
            driver.navigateToWorkspace()
            return
        }
        guard driver.pickContextItem(containing: "folder properties", "background context ▸ Folder Properties") else {
            driver.closeAnyMenu()
            reporter.fail("featFolderPropertiesFromBackground: no 'Folder Properties' item in the background context menu")
            driver.navigateToWorkspace()
            return
        }
        reporter.check(driver.waitForSheet(), "Properties sheet opened for the folder")
        reporter.check(
            driver.sheet()?.firstDescendant(where: AXMatch(textContains: "folder-props-uitest")) != nil,
            "the sheet is about the current folder ('folder-props-uitest'), not a file")
        reporter.check(driver.dismissSheet(), "Properties sheet dismissed")
        driver.navigateToWorkspace()
    }
}

extension Walkthrough {
    // MARK: - File Properties & Permissions

    func featFileProperties() {
        reporter.beginFeature("File Properties & Permissions")
        driver.navigateToWorkspace()
        // Context menu (not File ▸ Properties): the right-click guarantees the row is selected,
        // which the menu item needs.
        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "properties", "context ▸ Properties")
        else { return }
        reporter.check(driver.waitForSheet(), "Properties sheet opened")
        reporter.check(
            driver.sheet()?.firstDescendant(where: AXMatch(textContains: "permission")) != nil
                || driver.sheet()?.firstDescendant(where: AXMatch(textContains: "read")) != nil,
            "Properties sheet shows a permissions section")
        reporter.check(driver.dismissSheet(), "Properties sheet dismissed")
    }
}
