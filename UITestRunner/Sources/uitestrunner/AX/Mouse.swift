import CoreGraphics
import Foundation

/// Fallback pointer input for elements that expose no usable AX action (bare `AXPress` missing,
/// custom hit-testing). Coordinates are global top-left screen points — the same space
/// `AXElement.frame` reports, so an element-centre click needs no conversion.
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

        emit(.mouseMoved, at: point, button: .left, source: source, flags: [])
        Timing.pause(Timing.tap)
        emit(downType, at: point, button: button, source: source, flags: flags)
        Timing.pause(Timing.tap)
        emit(upType, at: point, button: button, source: source, flags: flags)
        Timing.pause(Timing.tap)
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

    static func doubleClick(center rect: CGRect, pid: pid_t) {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        click(at: point, pid: pid)
        Timing.pause(Timing.tap)
        let source = CGEventSource(stateID: .combinedSessionState)
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(
                mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { continue }
            event.setIntegerValueField(.mouseEventClickState, value: 2)
            event.post(tap: .cgSessionEventTap)
        }
        Timing.pause(Timing.tap)
    }

    private static func emit(
        _ type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton,
        source: CGEventSource?,
        flags: CGEventFlags) {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button) else { return }
        event.flags = flags
        event.post(tap: .cgSessionEventTap)
    }
}
