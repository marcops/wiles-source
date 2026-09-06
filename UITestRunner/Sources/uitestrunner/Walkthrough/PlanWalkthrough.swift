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

        let steps: [() -> Void] = [
            featNewAndCloseWindow, featSidebarSectionHeaders, featSectionCollapsePersists,
            featHideShowSection, featDirectoryTreeDrillIn, featSmartFoldersSectionRenders,
            featPathBarNavigation, featBackForwardEnclosing, featNewFolderInlineRename,
            featNewFileInlineRename, featRenameUndoRedo, featCutPaste, featCopyPaste,
            featKeyboardSelectionNav, featSelectAllThenClear, featSortOrder, featIconZoom,
            featQuickLook, featEmptyDirectory, featFooterTerminalButton, featTogglePreview,
            featSettingsTabs, featHelpSheet, featShortcutsHUD, featAboutSheet, featFeedbackSheet,
            // Phase B
            featChmodInProperties, featArchiveExtract, featFileShredder, featTagAssign, featCopyPath,
            featPDFMerge, featDuplicateFinderScan, featCompressWithPassword, featSmartFolderRoundTrip,
            featHTTPServerRoundTrip, featNavigationModeGnome, featPreferencePersistenceSweep,
            // Phase C
            featShiftClickRange, featCmdClickDeselectsOne, featClickEmptyAreaDeselects,
            featArrowPastLastRowStays, featRenameToExistingNameHandled, featRenameWithSlashSanitised,
            featNewFolderNameAutoIncrements, featSortByEachKeyReorders, featIconZoomClampsAtMinimum,
            featShowHiddenFilesToggle, featSearchNoMatchThenClear, featPropertiesShortcut,
            featTrashShortcutThenUndo, featPathBarRejectsBadPath, featKeyboardHistoryNav,
            featPlacesEntryNavigates, featListColumnHeaderClickSorts, featCompactDensityToggle,
            featAutoHideSidebarToggle,
            // Phase D
            featSearchScopeToggle, featSearchKindFilterToken, featSearchShortContentTermWarning,
            featQuickFilterImages, featStatusBarCountReflectsSelection, featPreviewPaneFollowsSelection,
            featSymlinkModalReopen, featAddRemoveFavorite, featTagFilterNavigates,
            featMoveCollisionSheet, featSmartFolderContextMenu,
        ]
        for step in steps {
            driver.recover()
            let started = Date()
            step()
            if Date().timeIntervalSince(started) > 45 {
                print("  ↻ relaunching after a slow step")
                try? driver.process.relaunch()
                driver.rebindToRelaunchedApp()
                _ = try? driver.mainWindow()
                driver.navigateToWorkspace()
            }
        }
    }
}
