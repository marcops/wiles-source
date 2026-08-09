import SwiftUI
import SwiftTerm
import AppKit

/// Keeps the PTY-backed terminal NSView (and its running shell process) alive across drawer
/// show/hide cycles. SwiftUI destroys and recreates NSViewRepresentable content whenever it's
/// conditionally removed from the view tree, which tears down SwiftTerm's view while its
/// background PTY-read thread can still be active — that's what was crashing on a fast
/// open/close. Holding the real instance here means SwiftUI can freely add/remove it from the
/// hierarchy (so the VSplitView divider disappears for real when closed) without ever
/// deallocating the process underneath.
@MainActor
final class TerminalViewCache {
    static let shared = TerminalViewCache()
    var view: LocalProcessTerminalView?
    var coordinator: IntegratedTerminalView.Coordinator?
    private init() {}
}
