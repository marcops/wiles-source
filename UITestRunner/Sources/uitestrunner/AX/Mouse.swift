import CoreGraphics
import Foundation

/// Fallback pointer input for elements that expose no usable AX action (bare `AXPress` missing,
/// custom hit-testing). Coordinates are global top-left screen points — the same space
/// `AXElement.frame` reports, so a element-centre click needs no conversion.
enum Mouse {
    static func click(at point: CGPoint, rightButton: Bool = false, pid: pid_t) {
        let button: CGMouseButton = rightButton ? .right : .left
        let downType: CGEventType = rightButton ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = rightButton ? .rightMouseUp : .leftMouseUp
        let source = CGEventSource(stateID: .combinedSessionState)

        emit(.mouseMoved, at: point, button: .left, source: source)
        Timing.pause(Timing.brief)
        emit(downType, at: point, button: button, source: source)
        Timing.pause(Timing.brief)
        emit(upType, at: point, button: button, source: source)
        Timing.pause(Timing.brief)
    }

    static func click(center rect: CGRect, rightButton: Bool = false, pid: pid_t) {
        click(at: CGPoint(x: rect.midX, y: rect.midY), rightButton: rightButton, pid: pid)
    }

    private static func emit(
        _ type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton,
        source: CGEventSource?) {
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button)?
            .post(tap: .cgSessionEventTap)
    }
}
