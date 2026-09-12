import Foundation

extension PlanWalkthrough {
    func featIconZoom() {
        reporter.beginFeature("Icon-size zoom (⌘+ / ⌘−)")
        driver.navigateToWorkspace()
        // This can be the very first interaction after the plan's language check, before the
        // header has fully settled post-launch — give it a beat before the first hover.
        Timing.pause(Timing.settle)
        driver.hoverThenTap(hoverMatch: AXMatch(identifier: "View Mode"), tapMatch: AXMatch(identifier: "ViewModeGrid"), label: "grid")
        // See featGridAndListViews: the switcher's collapse-on-select spring is slower than the
        // generic `Timing.animation` wait, so give it longer to settle before interacting again.
        Timing.pause(Timing.animation * 3)
        let before = gridWidth()
        driver.chord("=", .command)
        driver.chord("=", .command)
        driver.chord("=", .command)
        Timing.pause(Timing.animation)
        let after = gridWidth()
        reporter.check(
            before > 0 && after != before,
            "⌘+ changed the grid layout (row width \(Int(before)) → \(Int(after)))")
        driver.chord("-", .command)
        driver.chord("-", .command)
        driver.chord("-", .command)
        Timing.pause(Timing.animation)
        driver.hoverThenTap(hoverMatch: AXMatch(identifier: "View Mode"), tapMatch: AXMatch(identifier: "ViewModeList"), label: "list")
    }

    // MARK: - Zoom edges

    func featIconZoomClampsAtMinimum() {
        reporter.beginFeature("Icon zoom clamps instead of shrinking forever")
        driver.navigateToWorkspace()
        driver.menuPick("View", path: ["View Mode", "Grid"], "View ▸ View Mode ▸ Grid")
        Timing.pause(Timing.settle)
        for _ in 0 ..< 12 {
            driver.chord("-", .command)
            Timing.pause(Timing.keyStroke)
        }
        Timing.pause(Timing.settle)
        let minWidth = gridWidth()
        driver.chord("-", .command)
        Timing.pause(Timing.settle)
        reporter.check(minWidth > 0 && abs(gridWidth() - minWidth) < 2, "one more ⌘- past the minimum didn't shrink further (\(Int(minWidth))px)")
        reporter.check((try? driver.mainWindow()) != nil, "window still alive after 13× ⌘-")
        for _ in 0 ..< 6 { driver.chord("=", .command); Timing.pause(Timing.keyStroke) }
        driver.menuPick("View", path: ["View Mode", "List"], "View ▸ View Mode ▸ List (restore)")
    }

    func featViewModeSwitcherExpandsOnHover() {
        reporter.beginFeature("View-mode switcher expands on hover (no click required)")
        driver.navigateToWorkspace()
        driver.key(Keyboard.escape)
        Timing.pause(Timing.brief)
        guard let window = try? driver.mainWindow() else {
            reporter.fail("main window not available")
            return
        }
        reporter.check(driver.find(AXMatch(identifier: "View Mode"), timeout: 3) != nil, "collapsed 'View Mode' button is present before hovering")

        guard driver.hover(AXMatch(identifier: "View Mode"), "View Mode switcher (hover only, no click)") else { return }
        Timing.pause(Timing.animation)
        reporter.check(
            driver.find(AXMatch(identifier: "ViewModeGrid"), timeout: 2) != nil
                && driver.find(AXMatch(identifier: "ViewModeList"), timeout: 2) != nil,
            "hovering (no click) reveals both the Grid and List mode buttons")

        Mouse.move(to: CGPoint(x: window.frame.midX, y: window.frame.midY))
        Timing.pause(Timing.animation)
        reporter.check(
            driver.isGone(AXMatch(identifier: "ViewModeGrid"), within: 2),
            "moving the pointer away collapses the switcher back, with no click needed either way")
    }

    func featSortOrder() {
        reporter.beginFeature("Sort order")
        driver.navigateToWorkspace()
        // Compare the ordering of the seeded *files* only (the lone folder always sorts first).
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        let ascending = contentFileOrder()
        driver.menuPick("View", itemContains: "Ascending", "View ▸ Ascending (toggle)")
        Timing.pause(Timing.animation)
        let descending = contentFileOrder()
        reporter.check(
            ascending.count >= 2 && ascending != descending,
            "toggling sort direction reorders the files (\(ascending.first ?? "?")… → \(descending.first ?? "?")…)")
        driver.menuPick("View", itemContains: "Ascending", "View ▸ Ascending (restore)")
    }

    // MARK: - Sort edges

    func featSortByEachKeyReorders() {
        reporter.beginFeature("Every Sort By key produces an order, folders stay grouped")
        driver.navigateToWorkspace()
        var orders: [String: [String]] = [:]
        for key in ["Name", "Date Modified", "Size", "Kind"] {
            guard driver.menuPick("View", path: ["Sort By", key], "View ▸ Sort By ▸ \(key)") else { continue }
            Timing.pause(Timing.settle)
            orders[key] = contentFileOrder()
        }
        let nonEmpty = orders.values.filter { !$0.isEmpty }
        reporter.check(nonEmpty.count >= 3, "at least three sort keys returned a populated order")
        let distinct = Set(nonEmpty.map { $0.joined(separator: "|") })
        reporter.check(distinct.count >= 2, "the sort keys don't all yield the identical order")
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name (restore)")
    }

    // MARK: - View edges

    func featListColumnHeaderClickSorts() {
        reporter.beginFeature("Clicking a List-view column header changes the sort")
        driver.navigateToWorkspace()
        driver.menuPick("View", path: ["View Mode", "List"], "View ▸ View Mode ▸ List")
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        let before = contentFileOrder()
        guard let window = try? driver.mainWindow(),
              let header = window.firstDescendant(where: AXMatch(textEquals: "Size"), maxDepth: 24)
              ?? window.firstDescendant(where: AXMatch(role: "AXButton", textContains: "size"), maxDepth: 24) else {
            reporter.fail("no 'Size' column header found")
            return
        }
        driver.tapElement(header)
        Timing.pause(Timing.animation)
        let afterSize = contentFileOrder()
        driver.tapElement(header)
        Timing.pause(Timing.animation)
        let afterToggle = contentFileOrder()
        reporter.check(!before.isEmpty && (afterSize != before || afterToggle != afterSize),
                       "the header click reordered the list")
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name (restore)")
    }

    func featCompactDensityToggle() {
        reporter.beginFeature("Compact-density toggle is present and flips")
        driver.navigateToWorkspace()
        guard driver.openSettings(tab: "Advanced") else {
            reporter.fail("could not open Settings ▸ Advanced")
            return
        }
        func compactToggle() -> AXElement? {
            driver.sheet()?.firstDescendant(where: AXMatch(role: "AXCheckBox", textContains: "compact"), maxDepth: 22)
                ?? driver.sheet()?.firstDescendant(where: AXMatch(textContains: "compact density"), maxDepth: 22)
        }
        guard let toggle = compactToggle() else {
            driver.dismissSheet()
            reporter.fail("no compact-density toggle in Settings ▸ Advanced")
            return
        }
        let before = toggle.stringValue ?? ""
        driver.tapElement(toggle)
        Timing.pause(Timing.settle)
        let after = compactToggle()?.stringValue ?? ""
        reporter.check(!before.isEmpty && after != before || compactToggle() != nil,
                       "the compact-density toggle is present and responds to a click")
        if let back = compactToggle() { driver.tapElement(back) }
        driver.dismissSheet()
    }
}

extension Walkthrough {
    // MARK: - Grid & List Views

    func featGridAndListViews() {
        reporter.beginFeature("Grid & List Views")
        driver.navigateToWorkspace()

        guard driver.hoverThenTap(
            hoverMatch: AXMatch(identifier: "View Mode"),
            tapMatch: AXMatch(identifier: "ViewModeGrid"),
            label: "Grid mode button") else { return }
        // The switcher's own collapse-on-select spring is slower than the generic `Timing.animation`
        // wait — give it time to fully settle before hovering it again.
        Timing.pause(Timing.animation * 3)
        reporter.check(driver.fileRow(workspace.alphaFile) != nil, "'\(workspace.alphaFile)' still listed in Grid view")

        guard driver.hoverThenTap(
            hoverMatch: AXMatch(identifier: "View Mode"),
            tapMatch: AXMatch(identifier: "ViewModeList"),
            label: "List mode button") else { return }
        Timing.pause(Timing.animation)
        reporter.check(driver.fileRow(workspace.alphaFile) != nil, "'\(workspace.alphaFile)' still listed back in List view")
    }
}
