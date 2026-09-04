import Foundation
import Observation

/// Per-window UI presentation state: sheets, alerts, and their associated items that must NOT be
/// shared across multiple open Wiles windows. `AppState` is now constructed fresh per window (see
/// `MainContentView.init`); only its `preferences`/`transient` stores are shared instances —
/// `modal` (`ModalStore`, the error-alert state) is also per-window. Before that split, `AppState`
/// was a single instance shared by every window, so any field that lived on it (or on `ModalStore`)
/// showed up in every open window at once — e.g. opening "Properties" in one window popped the
/// properties sheet in every other window too. Anything toggled by an explicit, window-scoped user
/// action belongs here instead.
///
/// Instantiated once per window as `@State` in `MainContentView`, injected into that window's view
/// hierarchy via `.environment(_:)` and read by descendants with `@Environment(WindowUIState.self)`,
/// and published to the app-level menu commands in `WilesApp.swift` — which live outside any single
/// window's view hierarchy — via `.focusedSceneValue(\.windowUIState, windowUIState)` /
/// `@FocusedValue(\.windowUIState)`. Every error alert is per-window (each window's own `ModalStore`).
/// A background service with no window in front of it holds no `AppState`, so it reports via
/// `ErrorReporter` (GitBeacon) only — accepted; add a dedicated shared alert channel if one ever
/// needs to be user-visible.
@Observable
@MainActor
public final class WindowUIState {
    /// The one modal sheet this window is showing, if any — see `ActiveModal`. A single
    /// `.sheet(item:)` in `WilesModalSheets` switches on it.
    public var activeModal: ActiveModal?
    public var renameItem: FileItem? {
        didSet {
            guard renameItem == nil, oldValue != nil else { return }
            // One-shot: consume the closure as it fires. It's only ever set for the
            // newly-created-item rename session (`enterRenameForNewlyCreated`); leaving it set made
            // every *later* F2 / context-menu rename in the window also run this stale closure,
            // firing an extra `refreshCurrentDirectory()` on top of the ones commit()/cancel()
            // already do — 2-3 back-to-back directory reloads per rename (finding ML-139).
            let onCleared = onRenameCleared
            onRenameCleared = nil
            onCleared?()
        }
    }

    /// Set by `AppState.enterRenameForNewlyCreated` to clear `FileSystemStore.renamingURL` (the
    /// per-window refresh-suppression flag for the item being renamed) when that rename session's
    /// `renameItem` goes back to nil — whichever of its several cancel/commit paths did it. Consumed
    /// (set back to nil) the first time it fires, so it never outlives its one rename session.
    public var onRenameCleared: (() -> Void)?
    /// True while the integrated terminal drawer's PTY view is this window's first responder.
    /// Maintained by `GlobalKeyMonitor` on every key/scroll/click event. `GlobalKeyMonitor` yields
    /// keystrokes to the terminal when this is set, and `FileMenuCommands` disables the plain-key
    /// destructive menu items (Delete → Trash, Space → Quick Look) so their menu key equivalents
    /// can't fire from terminal input. See finding CH-321.
    public var isTerminalFocused: Bool = false
    public var showEmptyTrashAlert: Bool = false
    public var showDeleteConfirmAlert: Bool = false
    /// Permanent-delete (shred) confirmation. Separate from `showDeleteConfirmAlert` because that
    /// one moves to Trash (reversible) and this one is irreversible.
    public var showDeletePermanentlyConfirmAlert: Bool = false
    public var showShortcutsHUD: Bool = false
    /// A pending move name-collision decision (Replace / Keep Both / Cancel). Set by
    /// `promptMoveCollision` while a move loop is suspended waiting for the user; the sheet clears it.
    var moveCollisionPrompt: MoveCollisionPrompt?
    public var quickLookURL: URL?
    public var selectedFavoriteURL: URL?
    public var isEditingPath: Bool = false
    /// True while the header's search field is shown as an editable text box. When false and a
    /// search is active with a nameable context (a saved smart folder, or a lone `tag:` token),
    /// the header shows a non-editable name pill instead — clicking it flips this back on.
    public var isEditingSearch: Bool = false
    /// True while hovering a collapsed sidebar rail, temporarily widening it back out.
    public var isSidebarPeeking: Bool = false
    /// Keeps this window's terminal PTY/NSView alive across drawer show/hide cycles — per-window so
    /// opening the terminal drawer in two windows never shares the same shell process. See
    /// `TerminalViewCache`. Not `public`: `TerminalViewCache` itself is internal, and every reader
    /// (`IntegratedTerminalView`, `MainContentView`) lives in this same module.
    let terminalViewCache = TerminalViewCache()

    /// Backing store for `preferences`-mirrored defaults below — see that property's doc comment.
    private let preferences: PreferencesStore

    /// This window's own terminal drawer state, seeded from `preferences.view.showTerminalDrawer` (the
    /// persisted default for a *new* window) and written back on change so the next new window
    /// picks up the last-toggled state. Kept per-window — unlike a shared flag — so toggling the
    /// drawer in one window never spawns a PTY in every other open window.
    public var showTerminalDrawer: Bool {
        didSet {
            guard showTerminalDrawer != oldValue else { return }
            preferences.view.showTerminalDrawer = showTerminalDrawer
        }
    }

    /// This window's own sidebar width, mirrored the same way as `showTerminalDrawer` above.
    public var sidebarWidth: Double {
        didSet {
            guard sidebarWidth != oldValue else { return }
            preferences.view.sidebarWidth = sidebarWidth
        }
    }

    /// This window's trailing inspector, seeded from `preferences` and written back — see
    /// `showTerminalDrawer`. One enum, so preview/disk-usage can't both be on.
    public var trailingInspector: TrailingInspector {
        didSet {
            guard trailingInspector != oldValue else { return }
            preferences.view.trailingInspector = trailingInspector
        }
    }

    /// True while any sheet or alert owned by this window is on screen. `GlobalKeyMonitor` checks
    /// this before acting on a keypress so a Return/Delete meant for the presented alert's own
    /// button doesn't also fall through to the file list underneath (e.g. opening/renaming the
    /// selected item while a delete confirmation is up). Split into one bucket per presentation
    /// kind so a newly-added sheet/alert has an obvious place to be registered.
    public var isAnyModalPresented: Bool {
        activeModal != nil || showShortcutsHUD || anyAlertPresented
    }

    private var anyAlertPresented: Bool {
        showEmptyTrashAlert || showDeleteConfirmAlert || showDeletePermanentlyConfirmAlert
            || moveCollisionPrompt != nil
    }

    /// Suspends the caller until the user answers a move name-collision prompt for `itemName`.
    /// Pass `showApplyToAll: true` when more collisions may follow in the same batch.
    func promptMoveCollision(itemName: String, showApplyToAll: Bool) async -> MoveCollisionChoice {
        await withCheckedContinuation { continuation in
            moveCollisionPrompt = MoveCollisionPrompt(itemName: itemName, showApplyToAll: showApplyToAll) { [weak self] choice in
                self?.moveCollisionPrompt = nil
                continuation.resume(returning: choice)
            }
        }
    }

    /// Called from the window's `.onDisappear`. Answers any move name-collision prompt still
    /// awaiting a response with `.cancel` so a suspended move loop can't outlive the window if
    /// the sheet's own `.onDisappear` doesn't fire during an abrupt teardown.
    func tearDown() {
        moveCollisionPrompt?.resolve(MoveCollisionChoice(action: .cancel, applyToAll: false))
    }

    /// No default for `preferences`: a `WindowUIState()` with a throwaway store would load ~40
    /// defaults off disk and mirror a `PreferencesStore` disconnected from the shared one.
    public init(preferences: PreferencesStore) {
        self.preferences = preferences
        showTerminalDrawer = preferences.view.showTerminalDrawer
        sidebarWidth = preferences.view.sidebarWidth
        trailingInspector = preferences.view.trailingInspector
    }

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
    /// `.onTapGesture` (SWIFT_LANG_RULES.md `.contentShape` rule — custom tappable content, not a real `Button`/focusable control),
    /// which never shifts SwiftUI's `@FocusState` away from `InlineRenameField`'s `TextField`.
    /// `InlineRenameField` only commits/cancels on focus loss, so without this, clicking another
    /// item left the rename field showing on the old item while a different item became selected.
    /// `MainContentView` calls this from `.onChange(of: appState.selection.selectedURLs)`.
    public func cancelRenameIfSelectionChanged(selectedURLs: Set<URL>) {
        guard let renameItem else { return }
        guard selectedURLs != [renameItem.url] else { return }
        self.renameItem = nil
    }
}
