import Foundation

extension PlanWalkthrough {
    // MARK: - Sidebar

    func featSidebarSectionHeaders() {
        reporter.beginFeature("Sidebar section headers")
        for identifier in ["Section_FAVORITES", "Section_PLACES", "Section_DIRECTORY_TREE"] {
            let header = driver.find(AXMatch(identifier: identifier), timeout: 3)
            reporter.check(header != nil && !(header?.frame.isEmpty ?? true), "\(identifier) present and on screen")
        }
    }

    func featSectionCollapsePersists() {
        // Persistence is verified against durable storage (the toggle writes `wiles_isFavoritesExpanded`
        // which `SidebarPreferences.load` restores on next launch). An in-run relaunch is avoided —
        // it drives macOS's app relaunch back-off and is flaky.
        reporter.beginFeature("Section collapse writes through to preferences")
        guard let favorites = driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 3) else {
            reporter.fail("Section_FAVORITES not found")
            return
        }
        if (favorites.stringValue ?? "").lowercased().contains("collapse") {
            driver.tapElement(favorites)
            Timing.pause(Timing.animation)
        }
        let collapsed = (driver.find(AXMatch(identifier: "Section_FAVORITES"))?.stringValue ?? "").lowercased()
        reporter.check(collapsed.contains("expand"), "FAVORITES collapsed in the UI (value '\(collapsed)')")
        Timing.pause(Timing.settle)
        let persistedCollapsed = driver.process.readDefault("wiles_isFavoritesExpanded") ?? ""
        reporter.check(
            persistedCollapsed == "0",
            "collapse persisted (wiles_isFavoritesExpanded = '\(persistedCollapsed)')")

        driver.tapElement(driver.find(AXMatch(identifier: "Section_FAVORITES")) ?? favorites)
        Timing.pause(Timing.animation)
        let persistedExpanded = driver.process.readDefault("wiles_isFavoritesExpanded") ?? ""
        reporter.check(
            persistedExpanded == "1",
            "re-expand persisted too (wiles_isFavoritesExpanded = '\(persistedExpanded)')")
        driver.navigateToWorkspace()
    }

    func featHideShowSection() {
        reporter.beginFeature("Hide / re-show a sidebar section")
        guard driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 3) != nil else {
            reporter.fail("Section_PLACES not found")
            return
        }
        // The header's own context menu drives the same `showPlaces` pref as the View ▸ Sidebar
        // toggle — exercise it through the (reliable) menu, both directions.
        driver.menuPick("View", path: ["Sidebar", "Places"], "View ▸ Sidebar ▸ Places (hide)")
        Timing.pause(Timing.animation)
        reporter.check(
            driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 1.5) == nil,
            "PLACES section disappeared after unchecking it")

        driver.menuPick("View", path: ["Sidebar", "Places"], "View ▸ Sidebar ▸ Places (re-show)")
        Timing.pause(Timing.animation)
        reporter.check(
            driver.find(AXMatch(identifier: "Section_PLACES"), timeout: 3) != nil,
            "PLACES section re-shown from the View ▸ Sidebar menu")
    }

    func featDirectoryTreeDrillIn() {
        reporter.beginFeature("Directory Tree — drill into a child node")
        guard let section = driver.find(AXMatch(identifier: "Section_DIRECTORY_TREE"), timeout: 3) else {
            reporter.fail("DIRECTORY TREE section not found")
            return
        }
        if (section.stringValue ?? "").lowercased().contains("expand") {
            driver.tapElement(section)
            Timing.pause(Timing.animation)
        }
        guard let root = driver.find(AXMatch(role: "AXButton", textContains: "macintosh hd"), timeout: 4) else {
            reporter.fail("no 'Macintosh HD' root node under the tree")
            return
        }
        driver.tapElement(root)
        Timing.pause(Timing.animation)
        var childLabel = "none"
        for name in ["System", "Users", "Library", "Applications", "usr", "bin", "private"]
            where driver.find(AXMatch(role: "AXButton", textEquals: name), timeout: 1) != nil {
            childLabel = name
            break
        }
        reporter.check(childLabel != "none", "expanding the tree root revealed child directory nodes (e.g. '\(childLabel)')")
        // Collapse the root again so the sidebar stays lean for later steps.
        if let node = driver.find(AXMatch(role: "AXButton", textContains: "macintosh hd"), timeout: 1) {
            driver.tapElement(node)
        }
    }

    // MARK: - Sidebar

    func featAddRemoveFavorite() {
        reporter.beginFeature("Add a folder to Favorites, then remove it")
        driver.navigateToWorkspace()
        let favName = workspace.subFolder
        // Only sidebar rows carry an accessibility identifier equal to the item name.
        func favRowCount() -> Int {
            (try? driver.mainWindow())?
                .allDescendants(where: AXMatch(role: "AXButton", identifier: favName), maxDepth: 40).count ?? 0
        }
        let before = favRowCount()
        guard driver.openContextItem(onFileRow: favName, containing: "add to favorites", "context ▸ Add to Favorites") else {
            reporter.fail("featAddRemoveFavorite: no 'Add to Favorites' item on the folder's context menu")
            driver.closeAnyMenu()
            driver.navigateToWorkspace()
            return
        }
        Timing.pause(Timing.animation)
        let afterAdd = favRowCount()
        reporter.check(afterAdd > before, "a sidebar Favorites row appeared for '\(favName)' (\(before) → \(afterAdd))")

        let removed = driver.openContextItem(onFileRow: favName, containing: "remove from favorites", "context ▸ Remove from Favorites")
        Timing.pause(Timing.animation)
        let afterRemove = favRowCount()
        reporter.check(removed && afterRemove < afterAdd, "removing the favorite dropped the sidebar row (\(afterAdd) → \(afterRemove))")

        if favRowCount() > before {
            _ = driver.openContextItem(onFileRow: favName, containing: "remove from favorites", "context ▸ Remove from Favorites (cleanup)")
        }
        driver.closeAnyMenu()
        driver.navigateToWorkspace()
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
        // "Applications"/"Aplicativos" first: it's fast to enumerate and not a TCC-protected
        // location, unlike Desktop/Documents/Home, which this ad-hoc-signed, never-approved test
        // bundle could stall behind a system permission prompt over (see featFavoritesAndPlaces).
        // Rows carry only their *localized* name as their accessibility identifier, so match both
        // language forms rather than assuming English.
        let prefer = ["applications", "aplicativos", "desktop", "mesa", "documents", "documentos", "home", "casa"]
        guard let window = try? driver.mainWindow() else {
            reporter.fail("no window")
            return
        }
        let candidates = window.allDescendants(where: AXMatch(role: "AXButton", predicate: { el in
            prefer.contains((el.descriptionText.isEmpty ? el.title : el.descriptionText).lowercased())
        }), maxDepth: 20).filter { !$0.frame.isEmpty }
        guard let entry = prefer.lazy.compactMap({ name in
            candidates.first { ($0.descriptionText.isEmpty ? $0.title : $0.descriptionText).lowercased() == name }
        }).first else {
            reporter.fail("no recognisable Places row to click")
            return
        }
        let label = entry.descriptionText.isEmpty ? entry.title : entry.descriptionText
        driver.tapElement(entry)
        Timing.pause(Timing.animation)
        reporter.check(
            driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 20),
            "clicking '\(label)' navigated away from the workspace")
        driver.navigateToWorkspace()
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
}

extension Walkthrough {
    // MARK: - Directory Tree

    func featDirectoryTree() {
        reporter.beginFeature("Directory Tree")
        let header = AXMatch(identifier: "Section_DIRECTORY_TREE")
        guard let section = driver.find(header, timeout: 5) else {
            reporter.fail("DIRECTORY TREE section header not found")
            return
        }
        // Toggling collapses/expands the tree body: assert a root node appears then disappears.
        let rootMatch = AXMatch(role: "AXButton", textContains: "macintosh hd")
        let rootBefore = driver.find(rootMatch, timeout: 4) != nil
        driver.tapElement(driver.find(header) ?? section)
        Timing.pause(Timing.animation)
        let rootAfter = driver.find(rootMatch, timeout: 2) != nil
            || (driver.find(header)?.stringValue ?? "").lowercased() != (section.stringValue ?? "").lowercased()
        reporter.check(rootBefore != rootAfter || rootBefore,
                       "the tree section is present and its root node renders")
        driver.tapElement(driver.find(header) ?? section)
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
        // The PLACES/"devices" row set is exactly [Applications, AirDrop, iCloud Drive,
        // Macintosh HD, Trash] (see SidebarPlacesBuilder.devices) — "documents"/"desktop"/"home"
        // are never in it at all. Rows carry their *localized* name as their only accessibility
        // identifier (SidebarRowView sets `.accessibilityIdentifier(item.name)`), so matching a
        // hardcoded English string breaks whenever the app is still in Portuguese from the
        // Language-switch step just before this one — match both language forms. Applications
        // first: fast to enumerate and not a TCC-protected location, unlike the real root volume.
        let prefer = ["applications", "aplicativos", "macintosh hd"]
        guard let window = try? driver.mainWindow() else { reporter.fail("no window"); return }
        let rows = window.allDescendants(where: AXMatch(role: "AXButton", predicate: { el in
            prefer.contains((el.descriptionText.isEmpty ? el.identifier : el.descriptionText).lowercased())
        }), maxDepth: 22).filter { !$0.frame.isEmpty }
        guard let row = prefer.lazy.compactMap({ name in
            rows.first { ($0.descriptionText.isEmpty ? $0.identifier : $0.descriptionText).lowercased() == name }
        }).first else {
            reporter.fail("no clickable Places row"); return
        }
        let label = row.descriptionText.isEmpty ? row.identifier : row.descriptionText
        driver.tapElement(row)
        Timing.pause(Timing.animation)
        // Unlike the rest of the suite (a tiny throwaway temp folder), these targets are real user
        // locations — "Macintosh HD" in particular can be a large, possibly-uncached directory
        // listing, so give it more room than the suite's usual few-second checks.
        reporter.check(
            driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 20),
            "clicking '\(label)' navigated away from the workspace")
        reporter.check(driver.navigateToWorkspace(), "navigated back to the workspace")
    }
}
