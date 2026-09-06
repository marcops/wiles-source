import CoreGraphics
import Foundation

/// Pointer input via `CGEvent` posted to the session tap. Unlike keystrokes (which go straight to
/// the Wiles pid), synthetic mouse events need the window server's hit-testing, so they can't be
/// pid-targeted — during the brief moments the runner clicks, leave the physical mouse alone.
/// Coordinates are global top-left screen points — the same space `AXElement.frame` reports.
enum Mouse {
    static func click(
        at point: CGPoint,
        rightButton: Bool = false,
        modifiers: Keyboard.Modifiers = [],
        pid: pid_t) {
        let button: CGMouseButton = rightButton ? .right : .left
        let downType: CGEventType = rightButton ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = rightButton ? .rightMouseUp : .leftMouseUp
        let source = CGEventSource(stateID: .combinedSessionState)
        let flags = modifiers.flags

        emit(.mouseMoved, at: point, button: .left, source: source, flags: [], clickState: 0)
        Timing.pause(Timing.brief)
        emit(downType, at: point, button: button, source: source, flags: flags, clickState: 1)
        Timing.pause(Timing.brief)
        emit(upType, at: point, button: button, source: source, flags: flags, clickState: 1)
        Timing.pause(Timing.brief)
    }

    static func click(
        center rect: CGRect,
        rightButton: Bool = false,
        modifiers: Keyboard.Modifiers = [],
        pid: pid_t) {
        click(
            at: CGPoint(x: rect.midX, y: rect.midY),
            rightButton: rightButton,
            modifiers: modifiers,
            pid: pid)
    }

    /// Two click pairs fired back-to-back with `clickState` 1 then 2 — the sequence AppKit
    /// recognises as a double-click.
    static func doubleClick(center rect: CGRect, pid: pid_t) {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        let source = CGEventSource(stateID: .combinedSessionState)
        emit(.mouseMoved, at: point, button: .left, source: source, flags: [], clickState: 0)
        Timing.pause(Timing.brief)
        emit(.leftMouseDown, at: point, button: .left, source: source, flags: [], clickState: 1)
        emit(.leftMouseUp, at: point, button: .left, source: source, flags: [], clickState: 1)
        emit(.leftMouseDown, at: point, button: .left, source: source, flags: [], clickState: 2)
        emit(.leftMouseUp, at: point, button: .left, source: source, flags: [], clickState: 2)
        Timing.pause(Timing.brief)
    }

    private static func emit(
        _ type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton,
        source: CGEventSource?,
        flags: CGEventFlags,
        clickState: Int64) {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button) else { return }
        event.flags = flags
        if clickState > 0 {
            event.setIntegerValueField(.mouseEventClickState, value: clickState)
        }
        event.post(tap: .cgSessionEventTap)
    }
}
