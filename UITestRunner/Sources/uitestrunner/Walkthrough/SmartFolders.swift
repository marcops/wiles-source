import Foundation

extension PlanWalkthrough {
    func featSmartFoldersSectionRenders() {
        reporter.beginFeature("Smart Folders section renders")
        // The section only appears once at least one smart folder is saved (there is no
        // View ▸ Sidebar toggle for it). featSmartFolderRoundTrip covers the populated case;
        // here just confirm the sidebar itself renders its other sections.
        let smart = driver.find(AXMatch(identifier: "Section_SMART_FOLDERS"), timeout: 2)
        if smart != nil {
            reporter.pass("SMART FOLDERS section present")
        } else {
            reporter.check(
                driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 2) != nil,
                "sidebar renders (SMART FOLDERS appears after a folder is saved — see round-trip step)")
        }
    }

    // MARK: - Smart folder round trip

    func featSmartFolderRoundTrip() {
        reporter.beginFeature("Smart Folder — save a query and open it")
        driver.navigateToWorkspace()
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            _ = driver.activateSearch()
            Timing.pause(Timing.settle)
        }
        if let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) {
            driver.focusAndType(field, "alpha")
            Timing.pause(Timing.animation)
        }
        guard driver.tap(AXMatch(textContains: "save as smart folder"), "Save as Smart Folder", timeout: 4) else {
            driver.deactivateSearch()
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

        driver.deactivateSearch()
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
        // The smart-folder view only lists 'alpha' matches, so navigateToWorkspace's cheap
        // alpha-is-here check would false-pass; force a real nav that expects a non-match row.
        driver.deactivateSearch()
        _ = driver.navigateToPath(workspace.root.path, expectRow: workspace.subFolder, timeout: 6)
        driver.navigateToWorkspace()
    }
}

extension Walkthrough {
    // MARK: - Smart Folders

    func featSmartFolders() {
        reporter.beginFeature("Smart Folders")
        driver.navigateToWorkspace()
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            _ = driver.activateSearch()
            Timing.pause(Timing.settle)
        }
        if let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) {
            driver.tapElement(field)
            Timing.pause(Timing.brief)
            driver.type("uitest")
            Timing.pause(Timing.animation)
        }
        guard driver.tap(AXMatch(textContains: "save as smart folder"), "'Save as Smart Folder' control", timeout: 4) else {
            driver.deactivateSearch()
            return
        }
        reporter.check(driver.waitForSheet(), "Save Smart Folder sheet opened")
        reporter.check(driver.dismissSheet(), "Save Smart Folder sheet dismissed")
        driver.deactivateSearch()
        Timing.pause(Timing.settle)
        driver.navigateToWorkspace()
    }
}
