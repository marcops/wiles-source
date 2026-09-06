import Foundation

/// Every wait in the runner routes through here. One `scale` knob speeds the whole suite up or
/// slows it down once behaviour is stable, and no step hard-codes a literal delay.
enum Timing {
    /// Global multiplier applied to every delay and poll interval. `--fast` on the runner sets
    /// this lower; raise it on a slow machine.
    nonisolated(unsafe) static var scale: Double = 1.0

    /// Between synthesised key-up/down events.
    static var keyStroke: TimeInterval { 0.02 * scale }
    /// After a single click / keystroke, before reading the result.
    static var brief: TimeInterval { 0.2 * scale }
    /// After a UI action that triggers a state change (open a menu, toggle a section).
    static var settle: TimeInterval { 0.45 * scale }
    /// Wait out a SwiftUI transition / sheet present-dismiss animation.
    static var animation: TimeInterval { 0.7 * scale }
    /// Post-launch, before the first AX query.
    static var launch: TimeInterval { 2.0 * scale }
    /// Poll cadence for `waitFor…` loops.
    static var poll: TimeInterval { 0.25 * scale }

    static func pause(_ interval: TimeInterval) {
        Thread.sleep(forTimeInterval: interval)
    }
}
