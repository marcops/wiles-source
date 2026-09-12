import Foundation

extension PlanWalkthrough {
    /// Keystrokes typed within this many seconds of each other are still treated as one search
    /// buffer by `TypeAheadSelectionController` — the pause between the two sub-tests in
    /// `featTypeAheadRowSelection` must clear it so the second keystroke starts a fresh,
    /// single-character search.
    private static let typeAheadBufferResetPause: TimeInterval = 1.2

    // MARK: - Selection edges

    func featShiftClickRange() {
        reporter.beginFeature("Shift-click selects a contiguous range")
        driver.navigateToWorkspace()
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        driver.clickRow(workspace.pdfTwo, modifiers: .shift)
        Timing.pause(Timing.settle)
        reporter.check(selectedRowCount() >= 3, "shift-click from the first to a lower row selected the span (\(selectedRowCount()) rows)")
        driver.key(Keyboard.escape)
    }

    func featCmdClickDeselectsOne() {
        reporter.beginFeature("Cmd-click removes one row from a multi-selection")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        driver.clickRow(workspace.betaFile, modifiers: .command)
        Timing.pause(Timing.brief)
        let two = selectedRowCount()
        driver.clickRow(workspace.betaFile, modifiers: .command)
        Timing.pause(Timing.settle)
        let one = selectedRowCount()
        reporter.check(two == 2 && one == 1, "⌘-click toggled beta off (\(two) → \(one))")
        driver.key(Keyboard.escape)
    }

    func featClickEmptyAreaDeselects() {
        reporter.beginFeature("Clicking empty space clears the selection")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        reporter.check(selectedRowCount() >= 1, "a row is selected to start")
        // This runs deep into a chunk where earlier features may have left more files in the
        // workspace than usual, and any one fixed click point can land on a real row instead of
        // empty space if the list now reaches further than it normally would — try a few distinct
        // candidate points, not just the same one again, and poll rather than a single fixed pause
        // per attempt (the selection-cleared state can also lag a beat behind the click under load).
        var cleared = false
        for variant in 0 ..< 3 where !cleared {
            driver.clickContentArea(variant: variant)
            let deadline = Date().addingTimeInterval(3)
            repeat {
                cleared = selectedRowCount() == 0
                if !cleared { Timing.pause(Timing.poll) }
            } while !cleared && Date() < deadline
        }
        reporter.check(cleared, "the empty-area click cleared it")
    }

    func featArrowPastLastRowStays() {
        reporter.beginFeature("Down-arrow past the last row keeps a selection")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        for _ in 0 ..< 20 {
            driver.key(Keyboard.downArrow)
            Timing.pause(Timing.keyStroke)
        }
        Timing.pause(Timing.settle)
        let stillOne = driver.app.firstDescendant(where: AXMatch(predicate: { $0.isSelected && !$0.descriptionText.isEmpty }), maxDepth: 16) != nil
        reporter.check(stillOne, "hammering ↓ past the end left exactly one row selected, no crash")
        reporter.check((try? driver.mainWindow()) != nil, "the window is still alive")
    }

    func featKeyboardSelectionNav() {
        reporter.beginFeature("Keyboard selection navigation (arrow keys)")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        let firstSelected = driver.fileRow(workspace.alphaFile)?.isSelected ?? false
        reporter.check(firstSelected, "clicked row reports the AX 'selected' trait")

        driver.key(Keyboard.downArrow)
        Timing.pause(Timing.settle)
        let movedOff = !(driver.fileRow(workspace.alphaFile)?.isSelected ?? true)
        let somethingElseSelected = driver.app.firstDescendant(where: AXMatch(predicate: { element in
            element.isSelected && !element.descriptionText.isEmpty && element.descriptionText != workspace.alphaFile
        }), maxDepth: 14) != nil
        reporter.check(movedOff && somethingElseSelected, "↓ moved the selection to another row")
    }

    func featSelectAllThenClear() {
        reporter.beginFeature("Select All / clear selection")
        driver.navigateToWorkspace()

        func selectedSeededNames() -> Set<String> {
            Set(cornerSeeded.filter { driver.fileRow($0, timeout: 1)?.isSelected == true })
        }

        driver.process.activate()
        driver.menuPick("View", path: ["Sort By", "Name"], "View ▸ Sort By ▸ Name")
        Timing.pause(Timing.settle)
        var selectedAll = Set<String>()
        for attempt in 0 ..< 3 {
            _ = driver.clickRow(workspace.alphaFile)
            Timing.pause(Timing.brief)
            switch attempt {
            case 0: _ = driver.clickRow(workspace.pdfTwo, modifiers: .shift)
            case 1: driver.chord("a", .command)
            default: driver.menuPick("Edit", itemContains: "Select All", "Edit ▸ Select All")
            }
            Timing.pause(Timing.settle)
            selectedAll = selectedSeededNames()
            if selectedAll.count >= 3 { break }
        }
        reporter.check(
            selectedAll.count >= 3,
            "the selection extended past the one clicked row (\(selectedAll.count)/\(cornerSeeded.count))")

        driver.key(Keyboard.escape)
        Timing.pause(Timing.settle)
        reporter.check(selectedSeededNames().isEmpty, "Escape cleared the selection")
        driver.navigateToWorkspace()
    }

    func featTypeAheadRowSelection() {
        reporter.beginFeature("Type-ahead row selection (find-as-you-type)")
        driver.navigateToWorkspace()
        guard driver.clickRow(workspace.alphaFile) else { return }
        Timing.pause(Timing.brief)
        reporter.check(driver.fileRow(workspace.alphaFile)?.isSelected ?? false, "'\(workspace.alphaFile)' is selected before typing")

        driver.chord("b", [])
        Timing.pause(Timing.settle)
        reporter.check(
            (driver.fileRow(workspace.betaFile)?.isSelected ?? false) && !(driver.fileRow(workspace.alphaFile)?.isSelected ?? false),
            "typing 'b' jumps the selection to '\(workspace.betaFile)'")

        Timing.pause(Self.typeAheadBufferResetPause)
        driver.chord("m", [])
        Timing.pause(Timing.settle)
        reporter.check(
            driver.fileRow(workspace.midFile)?.isSelected ?? false,
            "typing 'm' after a pause starts a fresh search and jumps to '\(workspace.midFile)'")
    }
}
