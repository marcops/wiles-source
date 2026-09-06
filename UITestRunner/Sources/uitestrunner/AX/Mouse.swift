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
        let source = CGEventSource(stateID: .privateState)

        move(to: point, source: source, pid: pid)
        Thread.sleep(forTimeInterval: 0.05)
        emit(downType, at: point, button: button, source: source, pid: pid)
        Thread.sleep(forTimeInterval: 0.05)
        emit(upType, at: point, button: button, source: source, pid: pid)
        Thread.sleep(forTimeInterval: 0.08)
    }

    static func click(center rect: CGRect, rightButton: Bool = false, pid: pid_t) {
        click(at: CGPoint(x: rect.midX, y: rect.midY), rightButton: rightButton, pid: pid)
    }

    private static func move(to point: CGPoint, source: CGEventSource?, pid: pid_t) {
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
            .postToPid(pid)
    }

    private static func emit(
        _ type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton,
        source: CGEventSource?,
        pid: pid_t) {
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button)?
            .postToPid(pid)
    }
}
