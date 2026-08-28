import AppKit
import SwiftTerm
import SwiftUI

/// Keeps the PTY-backed terminal NSView (and its running shell process) alive across drawer
/// show/hide cycles. SwiftUI destroys and recreates NSViewRepresentable content whenever it's
/// conditionally removed from the view tree, which tears down SwiftTerm's view while its
/// background PTY-read thread can still be active — that's what was crashing on a fast
/// open/close. Holding the real instance here means SwiftUI can freely add/remove it from the
/// hierarchy (so the VSplitView divider disappears for real when closed) without ever
/// deallocating the process underneath.
///
/// One instance per window (owned by `WindowUIState`), not a shared singleton — a `.shared` cache
/// let two windows' terminal drawers reuse the same shell process/NSView.
@MainActor
final class TerminalViewCache {
    var view: LocalProcessTerminalView?
    var coordinator: IntegratedTerminalView.Coordinator?
    init() { }

    /// Called from `MainContentView.onDisappear` so a closed window doesn't leak its `/bin/zsh -l`.
    /// SwiftTerm exposes no public way to kill the PTY child from `LocalProcessTerminalView` (its
    /// `process` is module-internal and there is no killing `deinit`), so the best available teardown
    /// is to ask the login shell to exit, then drop our references. `view` is cleared first so
    /// `Coordinator.processTerminated` sees no cached view and doesn't respawn a replacement shell.
    func tearDown() {
        let closingView = view
        view = nil
        coordinator = nil
        closingView?.send(txt: "exit\r")
    }
}
