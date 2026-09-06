import Foundation

/// Walks every feature in wiles-public/FEATURES.md in order, against one app launch. Each `feat…`
/// step records its own checks through `reporter` and returns even on failure, so a single run
/// reports every broken feature at once.
struct Walkthrough {
    let driver: WilesDriver
    var reporter: Reporter { driver.reporter }
    var workspace: TempWorkspace { driver.workspace }

    func run() {
        featLaunchShell()
        featGridAndListViews()
        featDirectoryTree()
        featFavoritesAndPlaces()
        featSearch()
    }

    // MARK: - Launch & core shell

    private func featLaunchShell() {
        reporter.beginFeature("Launch & core shell")
        guard let window = try? driver.mainWindow() else {
            reporter.fail("main window never appeared")
            return
        }
        reporter.check(
            !window.frame.isEmpty,
            "main window on screen (\(Int(window.frame.width))×\(Int(window.frame.height)))")
        reporter.check(driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 6) != nil, "FAVORITES section present")
        reporter.check(driver.find(AXMatch(textEquals: "Status Bar"), timeout: 5) != nil, "footer Status Bar present")
        reporter.check(driver.navigateToWorkspace(), "navigated into seeded temp workspace")
        reporter.check(driver.fileRow(workspace.betaFile) != nil, "seeded file '\(workspace.betaFile)' listed")
    }
}
