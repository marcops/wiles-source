import AppKit
import QuickLook
import SwiftUI

/// Per-window focus key for `WindowUIState`. Published via `.focusedSceneValue` (not
/// `.focusedValue`, which needs an actual SwiftUI-focused control — this app uses custom
/// `NSEvent` monitors instead of native focus) so the menu commands in `WilesApp`, which live
/// outside any single window's view hierarchy, can read/toggle only the currently active window's
/// sheets, alerts, and shortcuts HUD. See `WindowUIState` for the full rationale.
private struct WindowUIStateKey: FocusedValueKey {
    typealias Value = WindowUIState
}

extension FocusedValues {
    var windowUIState: WindowUIState? {
        get { self[WindowUIStateKey.self] }
        set { self[WindowUIStateKey.self] = newValue }
    }
}

private struct AppStateKey: FocusedValueKey {
    typealias Value = AppState
}

extension FocusedValues {
    var appState: AppState? {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}

/// Scalar mirror of `windowUIState.renameItem != nil || windowUIState.isEditingPath`, published
/// from inside `MainContentView.body` so reading those properties there establishes an
/// `@Observable` dependency and forces `body` (and thus this republish) to re-run when either kind
/// of in-app text editing starts/ends. `Commands` scene rebuilding only reacts to an actual change
/// in a published `FocusedValues` entry — reading a nested mutable property of the stable
/// `windowUIState` object reference inside `WilesApp` does not, since `Commands` doesn't observe
/// `@Observable` mutations on an already-published reference the way a `View.body` does.
private struct IsTextFieldEditingActiveKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var isTextFieldEditingActive: Bool? {
        get { self[IsTextFieldEditingActiveKey.self] }
        set { self[IsTextFieldEditingActiveKey.self] = newValue }
    }
}
