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
            runBounded({ self.driver.recover(); step() }, seconds: 90)
        }
    }

    private final class Job: @unchecked Sendable {
        let body: () -> Void
        init(_ body: @escaping () -> Void) { self.body = body }
    }

    // Run a step on a worker thread; if it overruns, relaunch the app and move on. A wedged
    // interaction (hung modal, unreachable list) otherwise burns the whole run to the watchdog cap.
    private func runBounded(_ step: @escaping () -> Void, seconds: TimeInterval) {
        let done = DispatchSemaphore(value: 0)
        let job = Job { step(); done.signal() }
        Thread.detachNewThread { job.body() }
        if done.wait(timeout: .now() + seconds) == .timedOut {
            print("  ↻ step overran \(Int(seconds))s — relaunching")
            reporter.fail("step overran \(Int(seconds))s and was abandoned")
            try? driver.process.relaunch()
            driver.rebindToRelaunchedApp()
            _ = try? driver.mainWindow()
            driver.navigateToWorkspace()
        }
    }
}
