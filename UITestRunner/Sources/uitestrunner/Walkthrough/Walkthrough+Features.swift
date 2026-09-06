import Foundation

extension Walkthrough {
    // MARK: - Grid & List Views

    func featGridAndListViews() {
        reporter.beginFeature("Grid & List Views")
        driver.navigateToWorkspace()

        guard driver.tap(AXMatch(identifier: "View Mode"), "View Mode switcher") else { return }
        Timing.pause(Timing.settle)
        guard driver.tap(AXMatch(identifier: "ViewModeGrid"), "Grid mode button") else { return }
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile) != nil, "'\(workspace.alphaFile)' still listed in Grid view")

        guard driver.tap(AXMatch(identifier: "View Mode"), "View Mode switcher (re-expand)") else { return }
        Timing.pause(Timing.settle)
        guard driver.tap(AXMatch(identifier: "ViewModeList"), "List mode button") else { return }
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile) != nil, "'\(workspace.alphaFile)' still listed back in List view")
    }

    // MARK: - Directory Tree

    func featDirectoryTree() {
        reporter.beginFeature("Directory Tree")
        let header = AXMatch(identifier: "Section_DIRECTORY_TREE")
        guard let section = driver.find(header, timeout: 5) else {
            reporter.fail("DIRECTORY TREE section header not found")
            return
        }
        let collapsedValue = section.stringValue ?? ""
        driver.tapElement(section)
        Timing.pause(Timing.animation)
        let expandedValue = driver.find(header)?.stringValue ?? ""
        reporter.check(
            collapsedValue.lowercased() != expandedValue.lowercased(),
            "section toggle flipped state ('\(collapsedValue)' → '\(expandedValue)')")

        let rootNode = driver.find(AXMatch(role: "AXButton", textContains: "macintosh hd"), timeout: 4)
            ?? driver.find(AXMatch(role: "AXButton", textEquals: "/"), timeout: 2)
        reporter.check(rootNode != nil, "a filesystem root node rendered under the tree")

        driver.tapElement(section)
        Timing.pause(Timing.animation)
    }

    // MARK: - Favorites & Places

    func featFavoritesAndPlaces() {
        reporter.beginFeature("Favorites & Places")
        let places = AXMatch(identifier: "Section_PLACES")
        guard let section = driver.find(places, timeout: 5) else {
            reporter.fail("PLACES section header not found")
            return
        }
        if (section.stringValue ?? "").lowercased().contains("expand") {
            driver.tapElement(section)
            Timing.pause(Timing.settle)
        }
        guard driver.tap(AXMatch(identifier: "Applications"), "PLACES ▸ Applications row") else { return }
        let appBundle = driver.find(AXMatch(role: "AXButton", textContains: ".app"), timeout: 10)
        reporter.check(appBundle != nil, "clicking Applications listed a .app bundle")

        driver.tap(AXMatch(identifier: "chevron.left"), "Back button", timeout: 3)
        Timing.pause(Timing.animation)
        reporter.check(driver.navigateToWorkspace(), "navigated back to the workspace")
    }

    // MARK: - Search

    func featSearch() {
        reporter.beginFeature("Search")
        driver.navigateToWorkspace()
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            driver.tap(AXMatch(identifier: "magnifyingglass"), "search activate button", timeout: 3)
            Timing.pause(Timing.settle)
        }
        guard let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) else {
            reporter.fail("SearchTextField not found after activating search")
            return
        }
        driver.tapElement(field)
        Timing.pause(Timing.settle)
        driver.type("alpha")
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.betaFile, timeout: 3) == nil, "'\(workspace.betaFile)' filtered out by search 'alpha'")
        reporter.check(driver.fileRow(workspace.alphaFile, timeout: 3) != nil, "'\(workspace.alphaFile)' still matches search 'alpha'")

        driver.tap(AXMatch(identifier: "magnifyingglass"), "search toggle button (close)", timeout: 3)
        Timing.pause(Timing.animation)
        driver.navigateToWorkspace()
        reporter.check(driver.fileRow(workspace.betaFile, timeout: 4) != nil, "'\(workspace.betaFile)' returns after leaving search")
    }
}
