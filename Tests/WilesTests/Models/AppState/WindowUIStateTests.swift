import Foundation
@testable import Wiles

/// `WindowUIState` is a plain per-window presentation-state bag (sheets/alerts/HUD flags plus their
/// associated items), architecturally identical to `ModalStore` — see `ModalStoreTests.swift` for the
/// established pattern on a comparable class. No behavior beyond stored-property defaults/mutation.
@MainActor
public struct WindowUIStateTests {
    public static func run() {
        testDefaults()
        testMutation()
        testIsAnyModalPresented()
        testCancelRenameIfNavigated()
        testCancelRenameIfSelectionChanged()
        testPerWindowDefaultsSeedAndWriteBack()
        testMoveCollisionPromptResolvesOnceAndOnTearDown()
        testOnRenameClearedIsOneShot()
    }

    /// ML-139: `onRenameCleared` is set only for the newly-created-item rename session and must be
    /// consumed the first time `renameItem` clears — otherwise every later F2 / context-menu rename
    /// re-runs the stale closure and fires an extra directory refresh.
    private static func testOnRenameClearedIsOneShot() {
        let state = WindowUIState(preferences: PreferencesStore())
        let item = FileItem.load(url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wiles-onrenamecleared-\(UUID().uuidString).txt"))

        var fireCount = 0
        state.onRenameCleared = { fireCount += 1 }

        state.renameItem = item
        state.renameItem = nil // ends the "newly created" rename session
        report("Models/WindowUIState", "POS: onRenameCleared fires once when its rename session ends", result: fireCount == 1)
        report("Models/WindowUIState", "POS: onRenameCleared is cleared after firing", result: state.onRenameCleared == nil)

        // A later, unrelated rename (F2) must NOT re-run the consumed closure.
        state.renameItem = item
        state.renameItem = nil
        report(
            "Models/WindowUIState",
            "POS: a subsequent rename does not re-run the stale onRenameCleared (ML-139)",
            result: fireCount == 1)
    }

    /// A suspended move loop awaits `promptMoveCollision`. A prompt must never resolve twice (that
    /// would trap the continuation), and `tearDown()` must answer a still-pending prompt with
    /// `.cancel` so the loop can't outlive the window.
    private static func testMoveCollisionPromptResolvesOnceAndOnTearDown() {
        var resumeCount = 0
        var lastChoice: MoveCollisionChoice?
        let prompt = MoveCollisionPrompt(itemName: "x.txt", showApplyToAll: false) { choice in
            resumeCount += 1
            lastChoice = choice
        }
        prompt.resolve(MoveCollisionChoice(action: .replace, applyToAll: false))
        prompt.resolve(MoveCollisionChoice(action: .cancel, applyToAll: false))
        report(
            "Models/WindowUIState",
            "POS: MoveCollisionPrompt.resolve only takes effect once (first choice wins)",
            result: resumeCount == 1 && lastChoice?.action == .replace)

        resumeCount = 0
        let state = WindowUIState(preferences: PreferencesStore())
        state.moveCollisionPrompt = MoveCollisionPrompt(itemName: "y.txt", showApplyToAll: true) { choice in
            resumeCount += 1
            lastChoice = choice
        }
        state.tearDown()
        state.tearDown()
        report(
            "Models/WindowUIState",
            "POS: tearDown() answers a pending move-collision prompt with .cancel exactly once",
            result: resumeCount == 1 && lastChoice?.action == .cancel)
    }

    /// `showTerminalDrawer`/`sidebarWidth`/`trailingInspector` are seeded from the shared
    /// `PreferencesStore` at construction and written back on change, so each window has its own
    /// live value while still picking a sensible default for the *next* new window — see
    /// `PreferencesStore.sidebarWidth`'s doc comment. `trailingInspector` is one enum (M22), so
    /// preview/disk-usage can't both be on.
    private static func testPerWindowDefaultsSeedAndWriteBack() {
        let key = DefaultsKey.trailingInspector.rawValue
        let priorInspector = UserDefaults.standard.string(forKey: key)
        defer {
            if let priorInspector {
                UserDefaults.standard.set(priorInspector, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let preferences = PreferencesStore()
        preferences.view.showTerminalDrawer = true
        preferences.view.sidebarWidth = 222
        preferences.view.trailingInspector = .preview

        let state = WindowUIState(preferences: preferences)
        report("Models/WindowUIState", "POS: showTerminalDrawer is seeded from the preferences default", result: state.showTerminalDrawer)
        report("Models/WindowUIState", "POS: sidebarWidth is seeded from the preferences default", result: state.sidebarWidth == 222)
        report("Models/WindowUIState", "POS: trailingInspector is seeded from the preferences default", result: state.trailingInspector == .preview)

        state.showTerminalDrawer = false
        report("Models/WindowUIState", "POS: toggling showTerminalDrawer writes back to preferences", result: !preferences.view.showTerminalDrawer)

        state.trailingInspector = .diskUsage
        report(
            "Models/WindowUIState",
            "POS: setting the window's trailingInspector writes back to preferences",
            result: preferences.view.trailingInspector == .diskUsage && state.trailingInspector == .diskUsage)
    }

    private static func testDefaults() {
        let state = WindowUIState(preferences: PreferencesStore())
        report(
            "Models/WindowUIState",
            "POS: fresh instance has no active modal and no rename/quick-look payload",
            result: state.activeModal == nil
                && state.renameItem == nil
                && state.quickLookURL == nil
                && state.moveCollisionPrompt == nil)
        report(
            "Models/WindowUIState",
            "POS: fresh instance has all alert/HUD bools false",
            result: !state.showEmptyTrashAlert
                && !state.showDeleteConfirmAlert
                && !state.showDeletePermanentlyConfirmAlert
                && !state.showShortcutsHUD)
    }

    private static func testMutation() {
        let preferences = PreferencesStore()
        let state = WindowUIState(preferences: preferences)

        let item = FileItem.load(url: URL(fileURLWithPath: "/tmp/wiles-window-ui-state-test-item"))
        state.activeModal = .properties(item)
        report("Models/WindowUIState", "POS: activeModal holds the case it was set to", result: state.activeModal == .properties(item))

        state.showDeleteConfirmAlert = true
        report("Models/WindowUIState", "POS: showDeleteConfirmAlert holds the value it was set to", result: state.showDeleteConfirmAlert)
        state.showDeleteConfirmAlert = false
        report("Models/WindowUIState", "NEG: showDeleteConfirmAlert can be toggled back off", result: !state.showDeleteConfirmAlert)

        let urls = [URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")]
        state.activeModal = .passwordCompress(urls)
        report(
            "Models/WindowUIState",
            "POS: activeModal carries the passwordCompress payload it was set to",
            result: state.activeModal == .passwordCompress(urls))

        state.activeModal = .settings
        report("Models/WindowUIState", "POS: activeModal holds a no-payload case (.settings)", result: state.activeModal == .settings)

        report(
            "Models/WindowUIState",
            "POS: two separate instances don't share mutable state",
            result: WindowUIState(preferences: preferences).activeModal == nil && state.activeModal == .settings)
    }

    /// `isAnyModalPresented` gates `GlobalKeyMonitor` so a Return/Delete keypress meant for an
    /// alert's own default button doesn't fall through to the file list underneath (e.g. opening
    /// the selected item while a delete confirmation is up). Every flag it aggregates must flip
    /// the computed property, and it must go back to false once everything is dismissed.
    private static func testIsAnyModalPresented() {
        let state = WindowUIState(preferences: PreferencesStore())
        report("Models/WindowUIState", "NEG: isAnyModalPresented is false on a fresh instance", result: !state.isAnyModalPresented)

        state.showDeleteConfirmAlert = true
        report("Models/WindowUIState", "POS: isAnyModalPresented is true while showDeleteConfirmAlert is set", result: state.isAnyModalPresented)
        state.showDeleteConfirmAlert = false
        report("Models/WindowUIState", "NEG: isAnyModalPresented returns to false after the alert is dismissed", result: !state.isAnyModalPresented)

        state.activeModal = .settings
        report("Models/WindowUIState", "POS: isAnyModalPresented is true while activeModal is .settings", result: state.isAnyModalPresented)
        state.activeModal = nil

        state.activeModal = .httpShare(URL(fileURLWithPath: "/tmp"))
        report("Models/WindowUIState", "POS: isAnyModalPresented is true while activeModal carries an httpShare payload", result: state.isAnyModalPresented)
        state.activeModal = nil

        let item = FileItem.load(url: URL(fileURLWithPath: "/tmp/wiles-window-ui-state-modal-test-item"))
        state.activeModal = .properties(item)
        report("Models/WindowUIState", "POS: isAnyModalPresented is true while activeModal is .properties", result: state.isAnyModalPresented)
        state.activeModal = nil
        report("Models/WindowUIState", "NEG: isAnyModalPresented is false once activeModal is cleared", result: !state.isAnyModalPresented)

        testEveryModalFlagFlipsIsAnyModalPresented(on: state, sampleItem: item)

        report("Models/WindowUIState", "NEG: renameItem alone does not count as a blocking modal (inline rename, not a sheet)", result: {
            state.renameItem = item
            defer { state.renameItem = nil }
            return !state.isAnyModalPresented
        }())
    }

    /// Regression test for a real reported bug: start an in-place rename, navigate to a different
    /// folder before confirming/cancelling it, and the rename field used to stay "active" forever —
    /// `InlineRenameField`'s own commit/cancel path never runs because its row unmounts out from
    /// under it the moment the folder changes. `MainContentView` wires
    /// `windowUIState.cancelRenameIfNavigated(from:to:)` into `.onChange(of:
    /// appState.navigation.currentURL)`; this test drives the exact same real `AppState.navigateTo`
    /// call the app uses and asserts the method it hands off to actually clears `renameItem`.
    private static func testCancelRenameIfNavigated() {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: testTemporaryDirectory())
            .appendingPathComponent("WindowUIStateTests-\(UUID().uuidString)")
        let folderA = root.appendingPathComponent("FolderA")
        let folderB = root.appendingPathComponent("FolderB")
        try? fm.createDirectory(at: folderA, withIntermediateDirectories: true)
        try? fm.createDirectory(at: folderB, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let appState = AppState()
        let state = WindowUIState(preferences: appState.preferences)
        let item = FileItem.load(url: folderA.appendingPathComponent("renaming-me.txt"))

        appState.navigateTo(folderA, addToHistory: false)
        let urlBeforeNavigating = appState.navigation.currentURL
        state.renameItem = item

        state.cancelRenameIfNavigated(from: urlBeforeNavigating, to: urlBeforeNavigating)
        report("Models/WindowUIState", "NEG: navigating to the same folder (no real change) does not cancel an active rename", result: state.renameItem == item)

        appState.navigateTo(folderB, addToHistory: false)
        let urlAfterNavigating = appState.navigation.currentURL
        report(
            "Models/WindowUIState",
            "POS: AppState.navigateTo actually changed navigation.currentURL (test precondition)",
            result: urlBeforeNavigating != urlAfterNavigating)

        state.cancelRenameIfNavigated(from: urlBeforeNavigating, to: urlAfterNavigating)
        report("Models/WindowUIState", "POS: navigating to a different folder cancels an active rename", result: state.renameItem == nil)
    }

    /// Regression test for a real reported bug: start an in-place rename, then click a different
    /// item's icon/row. That selects the new item via a plain `.onTapGesture` (rule 33), which
    /// never moves keyboard focus away from `InlineRenameField`'s `TextField`, so the field's own
    /// focus-loss commit path never runs and the rename stayed active on the old item forever.
    private static func testCancelRenameIfSelectionChanged() {
        let state = WindowUIState(preferences: PreferencesStore())
        let renaming = FileItem.load(url: URL(fileURLWithPath: "/tmp/wiles-rename-selection-test-a.txt"))
        let other = FileItem.load(url: URL(fileURLWithPath: "/tmp/wiles-rename-selection-test-b.txt"))

        state.renameItem = renaming
        state.cancelRenameIfSelectionChanged(selectedURLs: [renaming.url])
        report("Models/WindowUIState", "NEG: selection staying on the item being renamed does not cancel it", result: state.renameItem == renaming)

        state.cancelRenameIfSelectionChanged(selectedURLs: [other.url])
        report("Models/WindowUIState", "POS: selecting a different item cancels an active rename", result: state.renameItem == nil)

        state.renameItem = renaming
        state.cancelRenameIfSelectionChanged(selectedURLs: [])
        report("Models/WindowUIState", "POS: clearing the selection entirely also cancels an active rename", result: state.renameItem == nil)

        report("Models/WindowUIState", "NEG: calling with no active rename is a harmless no-op", result: {
            state.renameItem = nil
            state.cancelRenameIfSelectionChanged(selectedURLs: [other.url])
            return state.renameItem == nil
        }())
    }

    /// Every sheet/alert/payload flag `isAnyModalPresented` aggregates must, on its own, flip it to
    /// true and back — guards against a flag being dropped from a bucket when the chain is regrouped.
    private static func testEveryModalFlagFlipsIsAnyModalPresented(on state: WindowUIState, sampleItem: FileItem) {
        let boolFlags: [(String, ReferenceWritableKeyPath<WindowUIState, Bool>)] = [
            ("showShortcutsHUD", \.showShortcutsHUD),
            ("showEmptyTrashAlert", \.showEmptyTrashAlert),
            ("showDeleteConfirmAlert", \.showDeleteConfirmAlert),
            ("showDeletePermanentlyConfirmAlert", \.showDeletePermanentlyConfirmAlert)
        ]
        for (name, keyPath) in boolFlags {
            state[keyPath: keyPath] = true
            report("Models/WindowUIState", "POS: isAnyModalPresented is true while \(name) is set", result: state.isAnyModalPresented)
            state[keyPath: keyPath] = false
        }

        for modal in ActiveModal.allSampleCases(item: sampleItem) {
            state.activeModal = modal
            report("Models/WindowUIState", "POS: isAnyModalPresented is true while activeModal is \(modal)", result: state.isAnyModalPresented)
            state.activeModal = nil
        }

        state.moveCollisionPrompt = MoveCollisionPrompt(itemName: "x", showApplyToAll: false) { _ in }
        report("Models/WindowUIState", "POS: isAnyModalPresented is true while a move-collision prompt is pending", result: state.isAnyModalPresented)
        state.moveCollisionPrompt = nil
        report("Models/WindowUIState", "NEG: isAnyModalPresented is false once every flag is cleared", result: !state.isAnyModalPresented)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
