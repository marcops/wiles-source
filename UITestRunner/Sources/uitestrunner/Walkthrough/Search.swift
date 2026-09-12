import Foundation

extension PlanWalkthrough {
    // MARK: - Search edges

    func featSearchNoMatchThenClear() {
        reporter.beginFeature("Search with no match shows the empty state, clearing restores the list")
        driver.navigateToWorkspace()
        guard driver.searchFor("zzzznomatch-uitest") != nil else {
            reporter.fail("search field never appeared")
            return
        }
        let noResults = driver.find(AXMatch(textContains: "no results"), timeout: 4) != nil
            || driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 3)
        reporter.check(noResults, "a non-matching query shows the empty / no-results state")
        driver.deactivateSearch()
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile, timeout: 5) != nil, "clearing the search brought the file list back")
    }

    // MARK: - Search

    func featSearchScopeToggle() {
        reporter.beginFeature("The Whole Mac toggle changes the search scope")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        driver.focusAndType(field, "uitest")
        Timing.pause(Timing.animation)
        let before = visibleSeededCount()
        guard let toggle = wholeMacToggle() else {
            reporter.fail("featSearchScopeToggle: no 'Whole Mac' search-scope toggle in the AX tree")
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        let wasSelected = toggle.isSelected
        let tapped = driver.tapElement(toggle)
        // The toggle's own `isSelected` trait can lag a beat behind the tap under load — poll
        // instead of checking once right after a single fixed pause.
        var flipped = false
        let deadline = Date().addingTimeInterval(3)
        repeat {
            flipped = (wholeMacToggle()?.isSelected ?? wasSelected) != wasSelected
            if !flipped { Timing.pause(Timing.poll) }
        } while !flipped && Date() < deadline
        let after = visibleSeededCount()
        reporter.check(tapped && flipped, "the Whole Mac toggle flipped its state (visible seeded matches \(before) → \(after))")
        if let restore = wholeMacToggle(), restore.isSelected != wasSelected { driver.tapElement(restore) }
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    func featSearchKindFilterToken() {
        reporter.beginFeature("A 'kind:' search token filters by file type")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        if let toggle = wholeMacToggle(), toggle.isSelected { driver.tapElement(toggle); Timing.pause(Timing.brief) }
        _ = field
        guard driver.searchFor("kind:image") != nil else {
            reporter.fail("featSearchKindFilterToken: could not type the 'kind:image' token into the field")
            driver.deactivateSearch()
            driver.navigateToWorkspace()
            return
        }
        reporter.check(driver.fileRow(workspace.imageFile, timeout: 8) != nil, "the image row survives the kind:image token")
        reporter.check(driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 10), "the text file is filtered out")
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    func featSearchShortContentTermWarning() {
        reporter.beginFeature("A too-short content search explains itself")
        driver.navigateToWorkspace()
        guard let field = revealSearchField() else {
            reporter.fail("search field never appeared")
            return
        }
        guard pickSearchFilter("file content") else {
            reporter.fail("featSearchShortContentTermWarning: could not switch the search scope to File Content")
            clearSearch(field)
            driver.navigateToWorkspace()
            return
        }
        Timing.pause(Timing.settle)
        _ = field
        driver.searchFor("a")
        let warned = driver.find(AXMatch(textContains: "at least 3 characters"), timeout: 3) != nil
            || driver.find(AXMatch(textContains: "search inside files"), timeout: 1) != nil
            || driver.find(AXMatch(textContains: "type at least"), timeout: 1) != nil
        reporter.check(warned, "a 1-character content term shows the 'type at least 3 characters' notice")
        _ = pickSearchFilter("file name")
        clearSearch(field)
        driver.navigateToWorkspace()
    }

    func featQuickFilterImages() {
        reporter.beginFeature("The Images filter narrows the list to pictures")
        driver.navigateToWorkspace()
        guard driver.searchFor("kind:image") != nil else {
            reporter.fail("search field never appeared")
            driver.navigateToWorkspace()
            return
        }
        let picsShown = driver.fileRow(workspace.imageFile, timeout: 4) != nil
        let textHidden = driver.isGone(AXMatch(textEquals: workspace.alphaFile), within: 4)
        reporter.check(picsShown && textHidden, "the image survives and non-image rows are hidden")
        driver.deactivateSearch()
        driver.navigateToWorkspace()
    }
}

extension Walkthrough {
    // MARK: - Search

    func featSearch() {
        reporter.beginFeature("Search")
        driver.navigateToWorkspace()
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            _ = driver.activateSearch()
            Timing.pause(Timing.settle)
        }
        guard let field = driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4) else {
            reporter.fail("SearchTextField not found after activating search")
            return
        }
        func seededVisible() -> Int {
            [workspace.alphaFile, workspace.betaFile, workspace.midFile, workspace.imageFile, workspace.zipFile]
                .filter { driver.fileRow($0, timeout: 1) != nil }.count
        }
        let before = seededVisible()
        reporter.check(driver.focusAndType(field, "alpha"), "search field accepted the query 'alpha'")
        driver.type("x")
        driver.key(Keyboard.delete)
        Timing.pause(Timing.animation)
        Timing.pause(Timing.animation)
        let after = seededVisible()
        reporter.check(after < before && driver.fileRow(workspace.alphaFile, timeout: 2) != nil,
                       "'alpha' narrowed the list to fewer rows, alpha still shown (\(before) → \(after))")

        driver.deactivateSearch()
        Timing.pause(Timing.animation)
        driver.navigateToWorkspace()
        reporter.check(driver.fileRow(workspace.betaFile, timeout: 4) != nil, "'\(workspace.betaFile)' returns after leaving search")
    }
}
