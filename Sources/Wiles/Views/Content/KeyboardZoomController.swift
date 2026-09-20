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
    /// Reads the live `activeShortcutsByCommand` store directly — no mode branching, same as every
    /// other raw-dispatch consumer of `ShortcutRegistry`.
    func handleZoomKeyDown(code: UInt16, appState: AppState) -> Bool {
        let store = appState.preferences.view.activeShortcutsByCommand
        if store[.zoomIn]?.physicalKeyCode == code {
            appState.preferences.view.iconSize = min(IconSizeToken.maxSize, appState.preferences.view.iconSize + IconSizeToken.step)
            return true
        }
        if store[.zoomOut]?.physicalKeyCode == code {
            appState.preferences.view.iconSize = max(IconSizeToken.minSize, appState.preferences.view.iconSize - IconSizeToken.step)
            return true
        }
        if store[.zoomReset]?.physicalKeyCode == code {
            appState.preferences.view.iconSize = IconSizeToken.defaultSize
            return true
        }
        return false
    }
}
