@testable import Wiles
import Foundation

/// `WindowUIState` is a plain per-window presentation-state bag (sheets/alerts/HUD flags plus their
/// associated items), architecturally identical to `ModalStore` — see `ModalStoreTests.swift` for the
/// established pattern on a comparable class. No behavior beyond stored-property defaults/mutation.
@MainActor
public struct WindowUIStateTests {
    public static func run() {
        testDefaults()
        testMutation()
        testIsAnyModalPresented()
    }

    private static func testDefaults() {
        let state = WindowUIState()
        report("Models/WindowUIState", "POS: fresh instance has all item/URL optionals nil", result: state.propertiesItem == nil
            && state.renameItem == nil
            && state.imageConverterItem == nil
            && state.symlinkItem == nil
            && state.httpShareFolderURL == nil
            && state.passwordCompressURLs == nil
            && state.inspectArchiveURL == nil)
        report("Models/WindowUIState", "POS: fresh instance has all sheet/alert/HUD bools false", result: !state.showBatchRenameSheet
            && !state.showNewFolderSheet
            && !state.showNewFileSheet
            && !state.showEmptyTrashAlert
            && !state.showDeleteConfirmAlert
            && !state.showConnectToServerSheet
            && !state.showAutoOrganizationSheet
            && !state.showHttpShareSheet
            && !state.showShortcutsHUD
            && !state.showSaveSmartFolderSheet
            && !state.showPasswordCompressSheet
            && !state.showArchiveInspectionSheet
            && !state.showHelpSheet
            && !state.showAboutSheet
            && !state.showSettingsSheet)
    }

    private static func testMutation() {
        let state = WindowUIState()

        let item = FileItem(url: URL(fileURLWithPath: "/tmp/wiles-window-ui-state-test-item"))
        state.propertiesItem = item
        report("Models/WindowUIState", "POS: propertiesItem holds the value it was set to", result: state.propertiesItem == item)

        state.showDeleteConfirmAlert = true
        report("Models/WindowUIState", "POS: showDeleteConfirmAlert holds the value it was set to", result: state.showDeleteConfirmAlert)
        state.showDeleteConfirmAlert = false
        report("Models/WindowUIState", "NEG: showDeleteConfirmAlert can be toggled back off", result: !state.showDeleteConfirmAlert)

        let urls = [URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")]
        state.passwordCompressURLs = urls
        report("Models/WindowUIState", "POS: passwordCompressURLs holds the array it was set to", result: state.passwordCompressURLs == urls)

        state.showSettingsSheet = true
        report("Models/WindowUIState", "POS: showSettingsSheet holds the value it was set to", result: state.showSettingsSheet)

        report("Models/WindowUIState", "POS: two separate instances don't share mutable state", result: WindowUIState().propertiesItem == nil && state.propertiesItem == item)
    }

    /// `isAnyModalPresented` gates `GlobalKeyMonitor` so a Return/Delete keypress meant for an
    /// alert's own default button doesn't fall through to the file list underneath (e.g. opening
    /// the selected item while a delete confirmation is up). Every flag it aggregates must flip
    /// the computed property, and it must go back to false once everything is dismissed.
    private static func testIsAnyModalPresented() {
        let state = WindowUIState()
        report("Models/WindowUIState", "NEG: isAnyModalPresented is false on a fresh instance", result: !state.isAnyModalPresented)

        state.showDeleteConfirmAlert = true
        report("Models/WindowUIState", "POS: isAnyModalPresented is true while showDeleteConfirmAlert is set", result: state.isAnyModalPresented)
        state.showDeleteConfirmAlert = false
        report("Models/WindowUIState", "NEG: isAnyModalPresented returns to false after the alert is dismissed", result: !state.isAnyModalPresented)

        state.showSettingsSheet = true
        report("Models/WindowUIState", "POS: isAnyModalPresented is true while showSettingsSheet is set", result: state.isAnyModalPresented)
        state.showSettingsSheet = false

        let item = FileItem(url: URL(fileURLWithPath: "/tmp/wiles-window-ui-state-modal-test-item"))
        state.propertiesItem = item
        report("Models/WindowUIState", "POS: isAnyModalPresented is true while propertiesItem is set", result: state.isAnyModalPresented)
        state.propertiesItem = nil
        report("Models/WindowUIState", "NEG: isAnyModalPresented is false once propertiesItem is cleared", result: !state.isAnyModalPresented)

        report("Models/WindowUIState", "NEG: renameItem alone does not count as a blocking modal (inline rename, not a sheet)", result: {
            state.renameItem = item
            defer { state.renameItem = nil }
            return !state.isAnyModalPresented
        }())
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
