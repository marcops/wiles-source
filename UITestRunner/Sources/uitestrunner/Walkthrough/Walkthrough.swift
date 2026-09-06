import Foundation

/// Walks every feature in wiles-public/FEATURES.md in order, against one app launch. Each `feat…`
/// step records its own checks through `driver.reporter` and returns even on failure, so a single
/// run reports every broken feature.
struct Walkthrough {
    let driver: WilesDriver
    private var reporter: Reporter { driver.reporter }

    func run() {
        featLaunchShell()
    }

    // MARK: - Shell

    private func featLaunchShell() {
        reporter.beginFeature("Launch & core shell")
        guard let window = try? driver.mainWindow() else {
            reporter.fail("main window never appeared")
            return
        }
        reporter.check(!window.frame.isEmpty, "main window is on screen (\(Int(window.frame.width))×\(Int(window.frame.height)))")

        let favorites = driver.find(AXMatch(identifier: "Section_FAVORITES"), timeout: 6)
        reporter.check(favorites != nil, "FAVORITES sidebar section present")

        let statusBar = driver.find(AXMatch(textEquals: "Status Bar"), timeout: 5)
        reporter.check(statusBar != nil, "footer Status Bar present")
    }
}
