import Foundation
import Observation

/// Per-window UI presentation state: sheets, alerts, and their associated items that must NOT be
/// shared across multiple open Wiles windows. `AppState` is a single instance shared by every
/// window, so any field that used to live on it (or on `ModalStore`) showed up in every open
/// window at once — e.g. opening "Properties" in one window popped the properties sheet in every
/// other window too. Anything toggled by an explicit, window-scoped user action belongs here
/// instead.
///
/// Instantiated once per window as `@State` in `MainContentView`, injected into that window's view
/// hierarchy via `.environment(_:)` and read by descendants with `@Environment(WindowUIState.self)`,
/// and published to the app-level menu commands in `WilesApp.swift` — which live outside any single
/// window's view hierarchy — via `.focusedSceneValue(\.windowUIState, windowUIState)` /
/// `@FocusedValue(\.windowUIState)`. Background-originated alerts with no window of their own
/// (`ModalStore.showErrorAlert`) intentionally stay on the shared `AppState`.
@Observable
@MainActor
public final class WindowUIState {
    public var propertiesItem: FileItem?
    public var renameItem: FileItem?
    public var imageConverterItem: FileItem?
    public var symlinkItem: FileItem?
    public var showBatchRenameSheet: Bool = false
    public var showNewFolderSheet: Bool = false
    public var showNewFileSheet: Bool = false
    public var showEmptyTrashAlert: Bool = false
    public var showDeleteConfirmAlert: Bool = false
    public var showConnectToServerSheet: Bool = false
    public var showAutoOrganizationSheet: Bool = false
    public var showDuplicateCleanerSheet: Bool = false
    public var showHttpShareSheet: Bool = false
    public var httpShareFolderURL: URL?
    public var showShortcutsHUD: Bool = false
    public var showSaveSmartFolderSheet: Bool = false
    public var showPasswordCompressSheet: Bool = false
    public var passwordCompressURLs: [URL]?
    public var inspectArchiveURL: URL?
    public var showArchiveInspectionSheet: Bool = false
    public var showHelpSheet: Bool = false
    public var showAboutSheet: Bool = false
    public var showSettingsSheet: Bool = false
    public var quickLookURL: URL?
    public var selectedFavoriteURL: URL?
    public var isEditingPath: Bool = false

    /// True while any sheet or alert owned by this window is on screen. `GlobalKeyMonitor` checks
    /// this before acting on a keypress so a Return/Delete meant for the presented alert's own
    /// button doesn't also fall through to the file list underneath (e.g. opening/renaming the
    /// selected item while a delete confirmation is up).
    public var isAnyModalPresented: Bool {
        showBatchRenameSheet || showNewFolderSheet || showNewFileSheet || showEmptyTrashAlert
            || showDeleteConfirmAlert || showConnectToServerSheet || showAutoOrganizationSheet
            || showDuplicateCleanerSheet || showHttpShareSheet || showSaveSmartFolderSheet
            || showPasswordCompressSheet || showArchiveInspectionSheet || showHelpSheet
            || showAboutSheet || showSettingsSheet || showShortcutsHUD
            || propertiesItem != nil || imageConverterItem != nil || symlinkItem != nil
    }

    public init() {}

    /// Cancels an active in-place rename in response to a folder navigation. The row rendering
    /// `InlineRenameField` belongs to whatever folder was current when rename began; once
    /// navigation moves elsewhere that row unmounts without ever running the field's own
    /// commit/cancel path, so a stale `renameItem` is left pointing at an item no longer on
    /// screen. `MainContentView` calls this from `.onChange(of: appState.navigation.currentURL)`.
    public func cancelRenameIfNavigated(from oldURL: URL, to newURL: URL) {
        guard oldURL != newURL else { return }
        renameItem = nil
    }

    /// Cancels an active in-place rename when the selection changes to something other than the
    /// item being renamed. Clicking a different item's icon/row selects it via a plain
    /// `.onTapGesture` (rule 33 — custom tappable content, not a real `Button`/focusable control),
    /// which never shifts SwiftUI's `@FocusState` away from `InlineRenameField`'s `TextField`.
    /// `InlineRenameField` only commits/cancels on focus loss, so without this, clicking another
    /// item left the rename field showing on the old item while a different item became selected.
    /// `MainContentView` calls this from `.onChange(of: appState.selectedURLs)`.
    public func cancelRenameIfSelectionChanged(selectedURLs: Set<URL>) {
        guard let renameItem else { return }
        guard selectedURLs != [renameItem.url] else { return }
        self.renameItem = nil
    }
}
