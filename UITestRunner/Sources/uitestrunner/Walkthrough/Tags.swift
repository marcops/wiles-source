import Foundation

extension PlanWalkthrough {
    func featTagFilterNavigates() {
        reporter.beginFeature("Clicking a sidebar tag filters the list to tagged files")
        driver.navigateToWorkspace()
        // wiles_showTags is seeded on by the run script; make sure the section is visible.
        if driver.find(AXMatch(identifier: "Section_TAGS"), timeout: 2) == nil {
            driver.menuPick("View", path: ["Sidebar", "Tags"], "View ▸ Sidebar ▸ Tags (show)")
            Timing.pause(Timing.animation)
        }
        func restoreTagsPref() {}

        // The sidebar's tag rows come from SystemTagsService.favoriteTags — the *real* Finder's
        // own favorite-tag prefs on this machine, not something derived from any file actually
        // being tagged. They exist before tagging anything, so "Red" specifically may not be
        // among them if this Mac's Finder tags were ever renamed/reordered/removed. Discover
        // whichever tag actually exists instead of assuming "Red".
        guard let anyTagRow = driver.find(AXMatch(role: "AXButton", predicate: { $0.identifier.hasPrefix("Tag_") }), timeout: 4)
            ?? driver.find(AXMatch(predicate: { $0.identifier.hasPrefix("Tag_") }), timeout: 1)
        else {
            reporter.fail("featTagFilterNavigates: no tag rows (Tag_*) in the sidebar at all")
            return
        }
        let tagName = String(anyTagRow.identifier.dropFirst("Tag_".count))
        guard !tagName.isEmpty else {
            reporter.fail("featTagFilterNavigates: tag row identifier had no name after 'Tag_'")
            return
        }

        guard driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "context ▸ Tags") else {
            reporter.fail("featTagFilterNavigates: no Tags submenu on the row context menu")
            restoreTagsPref()
            return
        }
        // The submenu needs a beat to populate after its parent is pressed (see featCopyPath) —
        // retry the leaf pick instead of trusting one immediate attempt.
        var pickedTag = false
        for attempt in 0 ..< 3 where !pickedTag {
            Timing.pause(Timing.settle)
            pickedTag = driver.pickContextItem(containing: tagName, "Tags ▸ \(tagName)")
            if !pickedTag, attempt < 2 {
                driver.closeAnyMenu()
                _ = driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "context ▸ Tags (retry)")
            }
        }
        guard pickedTag else {
            driver.closeAnyMenu()
            reporter.fail("featTagFilterNavigates: no '\(tagName)' item in the Tags submenu")
            restoreTagsPref()
            return
        }
        Timing.pause(Timing.animation)

        let tagRow = driver.find(AXMatch(role: "AXButton", identifier: "Tag_\(tagName)"), timeout: 4)
            ?? driver.find(AXMatch(identifier: "Tag_\(tagName)"), timeout: 1)
        guard let tagRow else {
            reporter.fail("featTagFilterNavigates: no \(tagName) tag row (Tag_\(tagName)) in the sidebar")
            driver.navigateToWorkspace()
            if driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "cleanup Tags") {
                _ = driver.pickContextItem(containing: tagName, "cleanup Tags ▸ \(tagName)")
            }
            driver.closeAnyMenu()
            restoreTagsPref()
            driver.navigateToWorkspace()
            return
        }
        driver.tapElement(tagRow)
        Timing.pause(Timing.animation)
        let filtered = driver.fileRow(workspace.alphaFile, timeout: 4) != nil
            && driver.isGone(AXMatch(textEquals: workspace.betaFile))
        let pathShowsTag = driver.find(AXMatch(textContains: tagName.lowercased()), timeout: 1) != nil
        reporter.check(filtered || pathShowsTag, "the \(tagName) tag filtered the list to tagged files or shows in the path bar")

        driver.navigateToWorkspace()
        if driver.openContextItem(onFileRow: workspace.alphaFile, containing: "tags", "cleanup Tags") {
            _ = driver.pickContextItem(containing: tagName, "cleanup Tags ▸ \(tagName) (toggle off)")
        }
        driver.closeAnyMenu()
        restoreTagsPref()
        driver.navigateToWorkspace()
    }

    // MARK: - Finder tags

    func featTagAssign() {
        reporter.beginFeature("Assign a Finder tag via context menu")
        driver.navigateToWorkspace()
        // Finder's tag names are in the *system* language (see featTagFilterNavigates) — discover
        // whichever one actually exists rather than assuming "Red".
        guard let anyTagRow = driver.find(AXMatch(predicate: { $0.identifier.hasPrefix("Tag_") }), timeout: 2) else {
            reporter.fail("featTagAssign: no tag rows (Tag_*) in the sidebar to learn a name from")
            return
        }
        let tagName = String(anyTagRow.identifier.dropFirst("Tag_".count))
        guard driver.rightClick(AXMatch(textEquals: workspace.betaFile), "'\(workspace.betaFile)' row (context)") else { return }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: "tags", "context ▸ Tags submenu") else {
            driver.closeAnyMenu()
            return
        }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: tagName, "Tags ▸ \(tagName)") else {
            driver.closeAnyMenu()
            return
        }
        Timing.pause(Timing.animation)
        let tags = fileTagNames(workspace.url(workspace.betaFile))
        reporter.check(!tags.isEmpty, "a colour tag was written to the file (\(tags))")
    }

    // MARK: - Clear All Tags

    func featClearAllTags() {
        reporter.beginFeature("Clear All Tags removes every tag from a file")
        driver.navigateToWorkspace()
        guard let anyTagRow = driver.find(AXMatch(predicate: { $0.identifier.hasPrefix("Tag_") }), timeout: 2) else {
            reporter.fail("featClearAllTags: no tag rows (Tag_*) in the sidebar to learn a name from")
            return
        }
        let tagName = String(anyTagRow.identifier.dropFirst("Tag_".count))

        // Tag alpha first so there's something for "Clear All Tags" to actually clear.
        guard driver.rightClick(AXMatch(textEquals: workspace.alphaFile), "'\(workspace.alphaFile)' row (context)") else { return }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: "tags", "context ▸ Tags submenu") else {
            driver.closeAnyMenu()
            return
        }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: tagName, "Tags ▸ \(tagName)") else {
            driver.closeAnyMenu()
            return
        }
        Timing.pause(Timing.animation)
        reporter.check(
            !fileTagNames(workspace.url(workspace.alphaFile)).isEmpty,
            "'\(workspace.alphaFile)' has a tag before clearing")

        // "Clear All Tags" only shows once the item actually has a tag — see
        // SharedFileItemContextMenu.tagsMenuContent's `!item.tags.isEmpty` guard.
        guard driver.rightClick(AXMatch(textEquals: workspace.alphaFile), "'\(workspace.alphaFile)' row (context, 2)", preClick: false) else { return }
        Timing.pause(Timing.settle)
        guard driver.pickContextItem(containing: "tags", "context ▸ Tags submenu (2)") else {
            driver.closeAnyMenu()
            return
        }
        Timing.pause(Timing.settle)
        // "Clear All Tags" is localized ("Limpar Todas as Etiquetas" in Portuguese) with no common
        // substring across languages — try both rather than assuming English.
        let clearedTags = driver.pickContextItem(containing: "clear all tags", "Tags ▸ Clear All Tags")
            || driver.pickContextItem(containing: "limpar todas as etiquetas", "Tags ▸ Limpar Todas as Etiquetas")
        guard clearedTags else {
            driver.closeAnyMenu()
            reporter.fail("featClearAllTags: no 'Clear All Tags' item in the Tags submenu")
            return
        }
        Timing.pause(Timing.animation)
        reporter.check(
            fileTagNames(workspace.url(workspace.alphaFile)).isEmpty,
            "'\(workspace.alphaFile)' has no tags after Clear All Tags")
    }
}

extension Walkthrough {
    // MARK: - Tags

    func featTags() {
        reporter.beginFeature("Tags")
        driver.navigateToWorkspace()
        let tagsVisible = driver.find(AXMatch(identifier: "Section_TAGS"), timeout: 2) != nil
        if tagsVisible {
            reporter.pass("TAGS sidebar section already visible")
        } else {
            guard driver.menuPick("View", path: ["Sidebar", "Show Tags"], "View ▸ Sidebar ▸ Show Tags") else { return }
            reporter.check(
                driver.find(AXMatch(identifier: "Section_TAGS"), timeout: 4) != nil,
                "TAGS sidebar section appeared after enabling 'Show Tags'")
            driver.menuPick("View", path: ["Sidebar", "Show Tags"], "View ▸ Sidebar ▸ Show Tags (restore)")
        }
    }
}
