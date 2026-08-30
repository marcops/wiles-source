import AppKit
import QuickLook
import SwiftUI

struct GlobalKeyMonitor: NSViewRepresentable {
    var appState: AppState
    var windowUIState: WindowUIState

    func makeNSView(context _: Context) -> KeyMonitorNSView {
        let view = KeyMonitorNSView()
        view.appState = appState
        view.windowUIState = windowUIState
        return view
    }

    func updateNSView(_ nsView: KeyMonitorNSView, context _: Context) {
        nsView.appState = appState
        nsView.windowUIState = windowUIState
    }

    /// Regression fix for a real reported bug: after a window's content view hierarchy was torn
    /// down (closing a second window, or SwiftUI rebuilding this view for any reason — window
    /// churn during a cross-app drag is one real trigger), this view's `NSEvent` monitor was never
    /// removed. Its handler captures `self` weakly and returns `nil` once `self` is gone, which
    /// per `NSEvent.addLocalMonitorForEvents` semantics swallows that event app-wide for every
    /// other monitor and the normal responder chain — so once leaked, every future keyDown/
    /// scrollWheel anywhere in the app was silently eaten forever, until relaunch. Fixed by
    /// removing the monitor on teardown, mirroring the sibling `ClickOutsideDetector.ClickView`,
    /// which already did this correctly. See `GlobalKeyMonitorUITests` for the regression test.
    class KeyMonitorNSView: NSView {
        var appState: AppState?
        var windowUIState: WindowUIState?
        private nonisolated(unsafe) var monitor: Any?
        private var zoomController = KeyboardZoomController()
        private let selectionNavigator = KeyboardSelectionNavigator()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
                    self?.processLocalEvent(event)
                }
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil {
                removeMonitor()
            }
        }

        override func removeFromSuperview() {
            super.removeFromSuperview()
            removeMonitor()
        }

        private func removeMonitor() {
            if let existingMonitor = monitor {
                NSEvent.removeMonitor(existingMonitor)
                monitor = nil
            }
        }

        deinit {
            if let existingMonitor = monitor {
                NSEvent.removeMonitor(existingMonitor)
            }
        }

        private func processLocalEvent(_ event: NSEvent) -> NSEvent? {
            guard let appState, let windowUIState else { return event }
            // `addLocalMonitorForEvents` is app-global: with N windows open there are N monitors,
            // each firing for every window's keyDown/scrollWheel. Without this guard, an arrow key
            // (or Backspace / F2 / Return) typed in window B also drives selection / trash / rename
            // in window A. Let the monitor belonging to the event's own window handle it.
            guard event.window == window else { return event }
            if let firstResponder = event.window?.firstResponder, firstResponder is NSTextView || firstResponder is NSTextField {
                return event
            }
            if windowUIState.isAnyModalPresented || appState.modal.showErrorAlert {
                return event
            }

            if event.type == .scrollWheel {
                return handleScrollEvent(event, appState: appState)
            } else if event.type == .keyDown {
                return handleKeyDownEvent(event, appState: appState, windowUIState: windowUIState)
            }
            return event
        }

        private func handleScrollEvent(_ event: NSEvent, appState: AppState) -> NSEvent? {
            let isCmd = event.modifierFlags.contains(.command)
            let isCtrl = event.modifierFlags.contains(.control)
            guard isCmd || isCtrl else { return event }

            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            guard delta != 0 else { return event }

            zoomController.applyScrollDelta(delta, appState: appState)
            return nil
        }

        private func handleKeyDownEvent(_ event: NSEvent, appState: AppState, windowUIState: WindowUIState) -> NSEvent? {
            let isCmd = event.modifierFlags.contains(.command)
            let isCtrl = event.modifierFlags.contains(.control)
            let code = event.keyCode

            if isCmd || isCtrl, zoomController.handleZoomKeyDown(code: code, appState: appState) {
                return nil
            }
            if selectionNavigator.handleNavigationKeyDown(code: code, isCmd: isCmd, appState: appState, windowUIState: windowUIState) {
                return nil
            }
            return event
        }
    }
}
