import Foundation

/// `--plan` mode: the broader TODO/UI_TEST_PLAN.md checklist (windows, navigation, content
/// operations, footer/inspector, the remaining modals) — everything beyond the FEATURES.md
/// surface the default walkthrough already covers. One launch, continue-on-failure.
struct PlanWalkthrough {
    let driver: WilesDriver
    var reporter: Reporter { driver.reporter }
    var workspace: TempWorkspace { driver.workspace }

    func run(only: [String] = []) {
        let steps: [(String, () -> Void)] = [
            ("featNewAndCloseWindow", featNewAndCloseWindow),
            ("featSidebarSectionHeaders", featSidebarSectionHeaders),
            ("featSectionCollapsePersists", featSectionCollapsePersists),
            ("featHideShowSection", featHideShowSection),
            ("featDirectoryTreeDrillIn", featDirectoryTreeDrillIn),
            ("featSmartFoldersSectionRenders", featSmartFoldersSectionRenders),
            ("featPathBarNavigation", featPathBarNavigation),
            ("featBackForwardEnclosing", featBackForwardEnclosing),
            ("featNewFolderInlineRename", featNewFolderInlineRename),
            ("featNewFileInlineRename", featNewFileInlineRename),
            ("featRenameUndoRedo", featRenameUndoRedo),
            ("featCutPaste", featCutPaste),
            ("featCopyPaste", featCopyPaste),
            ("featKeyboardSelectionNav", featKeyboardSelectionNav),
            ("featSelectAllThenClear", featSelectAllThenClear),
            ("featSortOrder", featSortOrder),
            ("featIconZoom", featIconZoom),
            ("featQuickLook", featQuickLook),
            ("featEmptyDirectory", featEmptyDirectory),
            ("featFooterTerminalButton", featFooterTerminalButton),
            ("featTogglePreview", featTogglePreview),
            ("featSettingsTabs", featSettingsTabs),
            ("featHelpSheet", featHelpSheet),
            ("featShortcutsHUD", featShortcutsHUD),
            ("featAboutSheet", featAboutSheet),
            ("featFeedbackSheet", featFeedbackSheet),
            ("featChmodInProperties", featChmodInProperties),
            ("featArchiveExtract", featArchiveExtract),
            ("featFileShredder", featFileShredder),
            ("featTagAssign", featTagAssign),
            ("featCopyPath", featCopyPath),
            ("featPDFMerge", featPDFMerge),
            ("featDuplicateFinderScan", featDuplicateFinderScan),
            ("featCompressWithPassword", featCompressWithPassword),
            ("featSmartFolderRoundTrip", featSmartFolderRoundTrip),
            ("featHTTPServerRoundTrip", featHTTPServerRoundTrip),
            ("featNavigationModeGnome", featNavigationModeGnome),
            ("featPreferencePersistenceSweep", featPreferencePersistenceSweep),
            ("featShiftClickRange", featShiftClickRange),
            ("featCmdClickDeselectsOne", featCmdClickDeselectsOne),
            ("featClickEmptyAreaDeselects", featClickEmptyAreaDeselects),
            ("featArrowPastLastRowStays", featArrowPastLastRowStays),
            ("featRenameToExistingNameHandled", featRenameToExistingNameHandled),
            ("featRenameWithSlashSanitised", featRenameWithSlashSanitised),
            ("featNewFolderNameAutoIncrements", featNewFolderNameAutoIncrements),
            ("featSortByEachKeyReorders", featSortByEachKeyReorders),
            ("featIconZoomClampsAtMinimum", featIconZoomClampsAtMinimum),
            ("featShowHiddenFilesToggle", featShowHiddenFilesToggle),
            ("featSearchNoMatchThenClear", featSearchNoMatchThenClear),
            ("featPropertiesShortcut", featPropertiesShortcut),
            ("featTrashShortcutThenUndo", featTrashShortcutThenUndo),
            ("featPathBarRejectsBadPath", featPathBarRejectsBadPath),
            ("featKeyboardHistoryNav", featKeyboardHistoryNav),
            ("featPlacesEntryNavigates", featPlacesEntryNavigates),
            ("featListColumnHeaderClickSorts", featListColumnHeaderClickSorts),
            ("featCompactDensityToggle", featCompactDensityToggle),
            ("featAutoHideSidebarToggle", featAutoHideSidebarToggle),
            ("featSearchScopeToggle", featSearchScopeToggle),
            ("featSearchKindFilterToken", featSearchKindFilterToken),
            ("featSearchShortContentTermWarning", featSearchShortContentTermWarning),
            ("featQuickFilterImages", featQuickFilterImages),
            ("featStatusBarCountReflectsSelection", featStatusBarCountReflectsSelection),
            ("featPreviewPaneFollowsSelection", featPreviewPaneFollowsSelection),
            ("featSymlinkModalReopen", featSymlinkModalReopen),
            ("featAddRemoveFavorite", featAddRemoveFavorite),
            ("featTagFilterNavigates", featTagFilterNavigates),
            ("featMoveCollisionSheet", featMoveCollisionSheet),
            ("featSmartFolderContextMenu", featSmartFolderContextMenu),
        ]
        let selected = only.isEmpty ? steps
            : steps.filter { name, _ in only.contains { name.localizedCaseInsensitiveContains($0) } }

        reporter.beginFeature("Language → English")
        reporter.check(
            driver.menuBarTitles().contains("Go") || driver.setLanguage(to: "English", expectMenu: "Go"),
            "app is in English")
        driver.dismissSheet()
        driver.navigateToWorkspace()

        for (_, step) in selected {
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
