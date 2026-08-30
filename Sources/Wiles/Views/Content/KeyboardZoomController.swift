import Foundation

/// Icon-size zoom computation extracted from `GlobalKeyMonitor.KeyMonitorNSView` so it's
/// unit-testable without an `NSView`/window. Holds only the scroll-wheel accumulator; callers
/// pass `AppState` per call rather than this type holding a reference to the view.
@MainActor
struct KeyboardZoomController {
    private var accumulatedScrollDelta: Double = 0

    /// Handles a Cmd/Ctrl + scroll-wheel delta, applying clamped icon-size steps to `appState`.
    mutating func applyScrollDelta(_ delta: Double, appState: AppState) {
        accumulatedScrollDelta += delta
        let stepMagnitude = IconSizeToken.scrollWheelStep
        while abs(accumulatedScrollDelta) >= stepMagnitude {
            let step = accumulatedScrollDelta > 0 ? stepMagnitude : -stepMagnitude
            appState.preferences.view.iconSize = min(IconSizeToken.maxSize, max(IconSizeToken.minSize, appState.preferences.view.iconSize + step))
            accumulatedScrollDelta -= step
        }
    }

    /// Handles a Cmd/Ctrl + `=`/`-`/`0` zoom key. Returns `true` if `code` was a zoom shortcut.
    /// Keycodes come from `ShortcutRegistry` so this and the cheat sheet can't disagree.
    func handleZoomKeyDown(code: UInt16, appState: AppState) -> Bool {
        if ShortcutRegistry.physicalKeyCodes(.zoomIn).contains(code) {
            appState.preferences.view.iconSize = min(IconSizeToken.maxSize, appState.preferences.view.iconSize + IconSizeToken.step)
            return true
        }
        if ShortcutRegistry.physicalKeyCodes(.zoomOut).contains(code) {
            appState.preferences.view.iconSize = max(IconSizeToken.minSize, appState.preferences.view.iconSize - IconSizeToken.step)
            return true
        }
        if ShortcutRegistry.physicalKeyCodes(.zoomReset).contains(code) {
            appState.preferences.view.iconSize = IconSizeToken.defaultSize
            return true
        }
        return false
    }
}
