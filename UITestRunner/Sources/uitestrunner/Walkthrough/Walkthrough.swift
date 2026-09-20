import Foundation

/// Walks every feature in wiles-public/FEATURES.md in order, against one app launch. Each `feat…`
/// step records its own checks through `reporter` and returns even on failure, so a single run
/// reports every broken feature at once.
struct Walkthrough {
    let driver: WilesDriver
    var reporter: Reporter { driver.reporter }
    var workspace: TempWorkspace { driver.workspace }

    func run(only: [String] = []) {
        let steps: [(String, () -> Void)] = [
            ("featSwitchToEnglish", featSwitchToEnglish),
            ("featLaunchShell", featLaunchShell),
            ("featGridAndListViews", featGridAndListViews),
            ("featDirectoryTree", featDirectoryTree),
            ("featFavoritesAndPlaces", featFavoritesAndPlaces),
            ("featSearch", featSearch),
            ("featFileProperties", featFileProperties),
            ("featSymbolicLinks", featSymbolicLinks),
            ("featCompressToZip", featCompressToZip),
            ("featUndoRedo", featUndoRedo),
            ("featBatchRename", featBatchRename),
            ("featImageConverter", featImageConverter),
            ("featArchiveInspector", featArchiveInspector),
            ("featDuplicateFinder", featDuplicateFinder),
            ("featIntegratedTerminal", featIntegratedTerminal),
            ("featDiskUsageVisualizer", featDiskUsageVisualizer),
            ("featConnectToServer", featConnectToServer),
            ("featAutoOrganization", featAutoOrganization),
            ("featHTTPSharing", featHTTPSharing),
            ("featTags", featTags),
            ("featSmartFolders", featSmartFolders),
            ("featAppearanceSettings", featAppearanceSettings),
            ("featShortcuts", featShortcuts),
        ]
        let selected = only.isEmpty ? steps
            : steps.filter { name, _ in name == "featSwitchToEnglish" || only.contains { name.localizedCaseInsensitiveContains($0) } }
        // One continuous session end to end — no mid-run relaunch. Wiles opens exactly once for
        // the whole suite (`featNewAndCloseWindow` opening/closing its own second *window* is a
        // feature test, not this).
        for (_, step) in selected {
            // Dismiss any sheet/menu a previous step left open before judging the next one by it —
            // PlanWalkthrough's loop already does this; Walkthrough's plain activate+navigate left
            // a leftover sheet from one step free to make the next step misread it as its own
            // (e.g. featAppearanceSettings finding openSettings()'s `sheet() != nil` fast path
            // pointing at someone else's still-open sheet instead of actually opening Settings).
            driver.recover()
            step()
        }
    }

    // MARK: - Force English through the Settings UI

    /// The suite's selectors past this point rely on English menu/label text, so step one is to
    /// actually drive Settings ▸ General ▸ Language → English (rather than pre-seeding a defaults
    /// key). Language endonyms ("English", "Português", …) render identically in every locale, so
    /// this works no matter what language the app launched in.
    private func featSwitchToEnglish() {
        reporter.beginFeature("Language switch (Settings ▸ General ▸ Language)")
        guard (try? driver.mainWindow()) != nil else {
            reporter.fail("main window never appeared")
            return
        }
        // App is seeded English. Round-trip through Português and back so the switcher is really
        // exercised — and check F1 (the footer free-space string re-localizes live).
        let toPT = driver.setLanguage(to: "Português", expectMenu: "Ir")
        reporter.check(toPT, "switching to Português flips the app menus (Ir / Ferramentas)")
        if toPT {
            let footerPT = driver.find(AXMatch(textContains: "livre"), timeout: 3) != nil
            reporter.check(footerPT, "F1: footer free-space string re-localized to Português ('… livre')")
        }
        let toEN = driver.setLanguage(to: "English", expectMenu: "Go")
        reporter.check(toEN, "switching back to English flips the menus back (Go / Tools)")
        let footerEN = driver.find(AXMatch(textContains: "free"), timeout: 3) != nil
        reporter.check(footerEN, "F1: footer free-space string re-localized back to English ('… free')")
        if !toEN {
            // Downstream steps need English — make one more attempt so a flake here doesn't cascade.
            driver.setLanguage(to: "English", expectMenu: "Go")
        }
        // The menu bar's title updates immediately, but other language-dependent UI (e.g. the
        // sidebar's cached `placeItems`, rebuilt only on its own `.onChange`) can lag a render
        // pass behind — `setLanguage`'s menu-text check can report success before that settles,
        // so downstream steps that match hardcoded English strings can still see Portuguese.
        Timing.pause(Timing.settle)
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
