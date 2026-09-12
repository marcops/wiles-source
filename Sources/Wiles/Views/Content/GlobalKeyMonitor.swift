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
    /// which already did this correctly.
    class KeyMonitorNSView: NSView {
        var appState: AppState?
        var windowUIState: WindowUIState?
        private nonisolated(unsafe) var monitor: Any?
        private var zoomController = KeyboardZoomController()
        private let selectionNavigator = KeyboardSelectionNavigator()
        private var typeAheadController = TypeAheadSelectionController()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [
                    .keyDown,
                    .scrollWheel,
                    .leftMouseUp,
                    .leftMouseDown,
                    .rightMouseDown
                ]) { [weak self] event in
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

        /// True when `firstResponder` is the integrated terminal's PTY view or a descendant of it.
        /// Pulled out as a pure function so the terminal-yield rule is unit-testable
        /// without an `NSWindow`/event.
        static func eventTargetsTerminal(firstResponder: NSResponder?, terminalView: NSView?) -> Bool {
            guard let terminalView, let responderView = firstResponder as? NSView else { return false }
            return responderView.isDescendant(of: terminalView)
        }

        private func processLocalEvent(_ event: NSEvent) -> NSEvent? {
            guard let appState, let windowUIState else { return event }
            // `addLocalMonitorForEvents` is app-global: with N windows open there are N monitors,
            // each firing for every window's keyDown/scrollWheel. Without this guard, an arrow key
            // (or Backspace / F2 / Return) typed in window B also drives selection / trash / rename
            // in window A. Let the monitor belonging to the event's own window handle it.
            guard event.window == window else { return event }
            // Keep the terminal-focus flag current for `FileMenuCommands` (menu key equivalents)
            // and yield every keystroke to the integrated terminal when it's focused — a custom
            // `NSView` from SwiftTerm, so the `NSTextView`/`NSTextField` check below never covers
            // it. Without this, Backspace in the terminal fires `.moveToTrash` on the list behind
            // it (data loss), and arrows / Return / F2 leak too.
            let terminalFocused = Self.eventTargetsTerminal(
                firstResponder: event.window?.firstResponder, terminalView: windowUIState.terminalViewCache.view)
            if windowUIState.isTerminalFocused != terminalFocused {
                windowUIState.isTerminalFocused = terminalFocused
            }
            if terminalFocused {
                yieldTerminalFocusIfClickedOutside(event, windowUIState: windowUIState)
                return event
            }
            if event.type == .leftMouseUp {
                return event
            }
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

        /// A click landing outside the terminal while it still holds first responder must yield
        /// explicitly: AppKit only reassigns first responder to whatever the click hits when that
        /// view itself accepts first responder, which plain SwiftUI content (rows, sidebar, empty
        /// space — all `.onTapGesture`-driven) never does. Without this, clicking anywhere outside
        /// the terminal leaves it as first responder and it keeps eating every keystroke.
        private func yieldTerminalFocusIfClickedOutside(_ event: NSEvent, windowUIState: WindowUIState) {
            guard event.type == .leftMouseDown || event.type == .rightMouseDown else { return }
            let hitView = event.window?.contentView?.hitTest(event.locationInWindow)
            guard !Self.eventTargetsTerminal(firstResponder: hitView, terminalView: windowUIState.terminalViewCache.view) else { return }
            event.window?.makeFirstResponder(nil)
            windowUIState.isTerminalFocused = false
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
            let isOption = event.modifierFlags.contains(.option)
            if !isCmd, !isCtrl, !isOption,
               typeAheadController.handleCharacterKeyDown(characters: event.charactersIgnoringModifiers, appState: appState) {
                return nil
            }
            return event
        }
    }
}
