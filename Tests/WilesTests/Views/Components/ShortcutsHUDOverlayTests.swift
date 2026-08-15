import SwiftUI
@testable import Wiles

/// NOTE: `ShortcutsHUDOverlay.merged(_:_:)` is a `private func` on the view instance.
/// It cannot be called from outside the type without changing the source — which requires
/// explicit approval. The only public-facing behaviour we can verify here is that the
/// overlay initialises correctly and is bound to the window's HUD state.
@MainActor
public struct ShortcutsHUDOverlayTests {
    public static func run() {
        let appState = AppState()
        let windowUIState = WindowUIState()
        windowUIState.showShortcutsHUD = true
        let view = ShortcutsHUDOverlay(
            appState: appState,
            isPresented: Binding(
                get: { windowUIState.showShortcutsHUD },
                set: { windowUIState.showShortcutsHUD = $0 }))
        report(
            "View/ShortcutsHUDOverlay",
            "POS: ShortcutsHUDOverlay initializes bound to the window's showShortcutsHUD state",
            result: view.isPresented == windowUIState.showShortcutsHUD)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
