import Foundation

extension PlanWalkthrough {
    // MARK: - Windows

    func featNewAndCloseWindow() {
        reporter.beginFeature("New / Close window (⌘N, ⌘W)")
        let before = driver.standardWindowCount
        driver.menuPick("File", itemContains: "New Window", "File ▸ New Window")
        Timing.pause(Timing.animation)
        let opened = driver.standardWindowCount
        reporter.check(opened == before + 1, "⌘N opened a second window (\(before) → \(opened))")

        driver.chord("w", .command)
        Timing.pause(Timing.animation)
        driver.resetWindowCache()
        let closed = driver.standardWindowCount
        reporter.check(closed == before, "⌘W closed it (\(opened) → \(closed))")
    }
}
