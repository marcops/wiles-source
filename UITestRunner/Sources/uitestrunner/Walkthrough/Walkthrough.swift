import Foundation

/// Walks every feature in wiles-public/FEATURES.md in order, against one app launch. Each `feat…`
/// step records its own checks through `reporter` and returns even on failure, so a single run
/// reports every broken feature at once.
struct Walkthrough {
    let driver: WilesDriver
    var reporter: Reporter { driver.reporter }
    var workspace: TempWorkspace { driver.workspace }

    func run() {
        featSwitchToEnglish()
        featLaunchShell()
        featGridAndListViews()
        featDirectoryTree()
        featFavoritesAndPlaces()
        featSearch()
        featFileProperties()
        featSymbolicLinks()
        featCompressToZip()
        featUndoRedo()
        featBatchRename()
        featImageConverter()
        featArchiveInspector()
        featDuplicateFinder()
        featIntegratedTerminal()
        featDiskUsageVisualizer()
        featConnectToServer()
        featAutoOrganization()
        featHTTPSharing()
        featTags()
        featSmartFolders()
        featAppearanceSettings()
    }

    // MARK: - Force English through the Settings UI

    /// The suite's selectors past this point rely on English menu/label text, so step one is to
    /// actually drive Settings ▸ General ▸ Language → English (rather than pre-seeding a defaults
    /// key). Language endonyms ("English", "Português", …) render identically in every locale, so
    /// this works no matter what language the app launched in.
    private func featSwitchToEnglish() {
        reporter.beginFeature("Switch language to English (Settings)")
        guard (try? driver.mainWindow()) != nil else {
            reporter.fail("main window never appeared")
            return
        }
        let before = driver.menuBarTitles()
        let nowEnglish = driver.switchToEnglishViaSettings()
        reporter.check(
            nowEnglish,
            "app menus are English after Settings ▸ General ▸ Language → English (before: [\(before.joined(separator: ","))])")
        let persisted = driver.process.readDefault("wiles_appLanguage") ?? ""
        reporter.check(
            persisted.contains("en") || nowEnglish,
            "English is the active language (wiles_appLanguage = '\(persisted.isEmpty ? "system-default" : persisted)')")
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
