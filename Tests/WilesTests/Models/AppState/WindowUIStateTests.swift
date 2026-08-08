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

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
