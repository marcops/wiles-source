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

    public init() {}
}
