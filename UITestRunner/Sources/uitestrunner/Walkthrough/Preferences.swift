import Foundation

extension PlanWalkthrough {
    // MARK: - Preference persistence sweep

    func featPreferencePersistenceSweep() {
        reporter.beginFeature("Preference persistence sweep")
        driver.navigateToWorkspace()

        driver.menuPick("View", path: ["View Mode", "Grid"], "View ▸ View Mode ▸ Grid")
        Timing.pause(Timing.animation)
        driver.menuPick("View", itemContains: "Show Terminal", "View ▸ Show Terminal")
        Timing.pause(Timing.settle)
        // Toggle the FAVORITES section twice so wiles_isFavoritesExpanded is actually written.
        if let fav = driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 3) {
            driver.tapElement(fav); Timing.pause(Timing.animation)
            driver.tapElement(driver.find(AXMatch(identifier: "Section_FAVORITES")) ?? fav); Timing.pause(Timing.animation)
        }

        let checks: [(String, (String) -> Bool)] = [
            ("wiles_viewMode", { $0.contains("Grid") }),
            ("wiles_appLanguage", { $0.contains("en") }),
            ("wiles_isFavoritesExpanded", { !$0.isEmpty }),
        ]
        for (key, valid) in checks {
            let value = driver.process.readDefault(key) ?? ""
            reporter.check(valid(value), "\(key) persisted ('\(value)')")
        }

        driver.menuPick("View", itemContains: "Hide Terminal", "View ▸ Hide Terminal (restore)")
        driver.menuPick("View", path: ["View Mode", "List"], "View ▸ View Mode ▸ List (restore)")
    }
}
