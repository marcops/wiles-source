import SwiftUI
import QuickLook
import AppKit

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
