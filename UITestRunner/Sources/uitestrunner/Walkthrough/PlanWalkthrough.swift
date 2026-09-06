import Foundation

/// `--plan` mode: the broader TODO/UI_TEST_PLAN.md checklist (windows, navigation, content
/// operations, footer/inspector, the remaining modals) — everything beyond the FEATURES.md
/// surface the default walkthrough already covers. One launch, continue-on-failure.
struct PlanWalkthrough {
    let driver: WilesDriver
    var reporter: Reporter { driver.reporter }
    var workspace: TempWorkspace { driver.workspace }

    func run() {
        reporter.beginFeature("Language → English")
        reporter.check(
            driver.menuBarTitles().contains("Go") || driver.setLanguage(to: "English", expectMenu: "Go"),
            "app is in English")
        driver.navigateToWorkspace()

        featNewAndCloseWindow()
        featSidebarSectionHeaders()
        featSectionCollapsePersists()
        featHideShowSection()
        featDirectoryTreeDrillIn()
        featSmartFoldersSectionRenders()
        featPathBarNavigation()
        featBackForwardEnclosing()
        featNewFolderInlineRename()
        featNewFileInlineRename()
        featRenameUndoRedo()
        featCutPaste()
        featCopyPaste()
        featKeyboardSelectionNav()
        featSelectAllThenClear()
        featSortOrder()
        featIconZoom()
        featQuickLook()
        featEmptyDirectory()
        featFooterTerminalButton()
        featTogglePreview()
        featSettingsTabs()
        featHelpSheet()
        featShortcutsHUD()
        featAboutSheet()
        featFeedbackSheet()

        // Phase B — deeper behaviour
        featChmodInProperties()
        featArchiveExtract()
        featFileShredder()
        featTagAssign()
        featCopyPath()
        featPDFMerge()
        featDuplicateFinderScan()
        featCompressWithPassword()
        featSmartFolderRoundTrip()
        featHTTPServerRoundTrip()
        featNavigationModeGnome()
        featPreferencePersistenceSweep()
    }
}
