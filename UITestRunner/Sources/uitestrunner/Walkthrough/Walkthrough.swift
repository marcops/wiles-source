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
        driver.chord(",", .command)
        guard driver.waitForSheet() else {
            reporter.fail("Settings sheet did not open on ⌘,")
            return
        }
        guard let languagePicker = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXPopUpButton")) else {
            reporter.fail("language picker (first AXPopUpButton on the General tab) not found")
            driver.dismissSheet()
            return
        }
        let before = driver.menuBarTitles()
        driver.tapElement(languagePicker)
        Timing.pause(Timing.settle)
        guard let englishItem = driver.app.waitForDescendant(
            where: AXMatch(role: "AXMenuItem", textEquals: "English"), timeout: 3) else {
            reporter.fail("'English' option not in the language picker menu")
            driver.closeAnyMenu()
            driver.dismissSheet()
            return
        }
        _ = englishItem.perform(AXAction.pick) || englishItem.press()
        Timing.pause(Timing.animation)
        reporter.check(driver.dismissSheet(), "Settings dismissed after choosing English")

        // A language switch rebuilds the whole SwiftUI tree; let it fully re-render and re-focus
        // before the feature steps start querying it.
        Timing.pause(Timing.launch)
        driver.process.activate()
        Timing.pause(Timing.settle)
        let after = driver.menuBarTitles()
        let beforeList = before.joined(separator: ",")
        reporter.check(
            after.contains("Go") && after.contains("Tools") && after.contains("View"),
            "app menus are in English after the switch (Go / Tools present; before: [\(beforeList)])")
        let persisted = driver.process.readDefault("wiles_appLanguage") ?? ""
        reporter.check(
            persisted.contains("en") || after.contains("Go"),
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
