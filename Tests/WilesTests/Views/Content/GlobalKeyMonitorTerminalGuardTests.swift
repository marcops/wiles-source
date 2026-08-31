import AppKit
@testable import Wiles

/// Covers `GlobalKeyMonitor.KeyMonitorNSView.eventTargetsTerminal` — the pure predicate that makes
/// the global key monitor yield keystrokes to the integrated terminal instead of firing list
/// actions (Backspace → Trash, arrows, Return, F2). Finding CH-321.
@MainActor
public struct GlobalKeyMonitorTerminalGuardTests {
    public static func run() {
        let cat = "View/GlobalKeyMonitor"
        typealias Guard = GlobalKeyMonitor.KeyMonitorNSView

        let terminal = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let child = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        terminal.addSubview(child)
        let grandchild = NSView(frame: .zero)
        child.addSubview(grandchild)
        let unrelated = NSView(frame: .zero)

        TestReporter.report(
            cat, "NEG: no terminal view and no responder → not targeting terminal",
            result: !Guard.eventTargetsTerminal(firstResponder: nil, terminalView: nil))

        TestReporter.report(
            cat, "NEG: terminal exists but no first responder → false",
            result: !Guard.eventTargetsTerminal(firstResponder: nil, terminalView: terminal))

        TestReporter.report(
            cat, "POS: first responder IS the terminal view → true",
            result: Guard.eventTargetsTerminal(firstResponder: terminal, terminalView: terminal))

        TestReporter.report(
            cat, "POS: first responder is a direct subview of the terminal → true",
            result: Guard.eventTargetsTerminal(firstResponder: child, terminalView: terminal))

        TestReporter.report(
            cat, "POS: first responder is a deep descendant of the terminal → true",
            result: Guard.eventTargetsTerminal(firstResponder: grandchild, terminalView: terminal))

        TestReporter.report(
            cat, "NEG: first responder is an unrelated view → false",
            result: !Guard.eventTargetsTerminal(firstResponder: unrelated, terminalView: terminal))

        TestReporter.report(
            cat, "NEG: first responder is a non-view responder (window) → false",
            result: !Guard.eventTargetsTerminal(firstResponder: NSWindow(), terminalView: terminal))

        TestReporter.report(
            cat, "NEG: responder inside terminal but terminal view is nil → false",
            result: !Guard.eventTargetsTerminal(firstResponder: child, terminalView: nil))
    }
}
