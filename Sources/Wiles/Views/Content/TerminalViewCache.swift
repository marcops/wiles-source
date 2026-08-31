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
    /// Captured by `IntegratedTerminalView.makeNSView` right after `startProcess`, when SwiftTerm's
    /// internal layout is known-good — so teardown doesn't hinge on the same reflection still
    /// resolving after a future SwiftTerm bump (that would silently leak the shell). Teardown-time
    /// reflection stays as a second fallback, then `exit`.
    var shellPid: pid_t?
    init() { }

    /// Called from `MainContentView.onDisappear` so a closed window doesn't leak its `/bin/zsh -l`
    /// (and whatever it's running — `vim`, `tail -f` — which would swallow a plain `exit`). `view` is
    /// cleared first so `Coordinator.processTerminated` sees no cached view and doesn't respawn.
    func tearDown() {
        let closingView = view
        let capturedPid = shellPid
        view = nil
        coordinator = nil
        shellPid = nil
        // SIGKILL the shell's whole process group (login shell in a fresh PTY is the group leader),
        // reaching any foreground child. Prefer the pid captured at spawn; reflect again, then
        // `send("exit")`, only if that's missing.
        if let pid = capturedPid ?? Self.reflectShellPid(of: closingView), pid > 0 {
            if kill(-pid, SIGKILL) != 0 {
                kill(pid, SIGKILL)
            }
        } else {
            closingView?.send(txt: "exit\r")
        }
    }

    /// SwiftTerm keeps `LocalProcessTerminalView.process` (and thus `shellPid`) module-internal, so
    /// read it reflectively. Best-effort: `nil` when the layout changes and we fall back to `exit`.
    static func reflectShellPid(of view: LocalProcessTerminalView?) -> pid_t? {
        guard let view else { return nil }
        guard let process = Mirror(reflecting: view).children.first(where: { $0.label == "process" })?.value else { return nil }
        return Mirror(reflecting: process).children.first { $0.label == "shellPid" }?.value as? pid_t
    }
}
