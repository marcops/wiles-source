import Foundation

/// Every wait in the runner routes through here. `scale` multiplies every delay — raise it on a
/// slow machine or to watch a run, lower it (`--fast`) to blast through. The base values are
/// already tight: the suite is meant to be followed from the log, not by eye.
enum Timing {
    /// Global multiplier. `--scale <n>` / `--fast` set this on the runner.
    nonisolated(unsafe) static var scale: Double = 1.0

    /// Between synthesised key-up/down events.
    static var keyStroke: TimeInterval { 0.006 * scale }
    /// Between the down/up phases of a synthesised mouse click.
    static var tap: TimeInterval { 0.03 * scale }
    /// After a single click / keystroke, before reading the result.
    static var brief: TimeInterval { 0.07 * scale }
    /// After a UI action that triggers a state change (open a menu, toggle a section).
    static var settle: TimeInterval { 0.16 * scale }
    /// Wait out a SwiftUI transition / sheet present-dismiss animation.
    static var animation: TimeInterval { 0.28 * scale }
    /// Post-launch, before the first AX query.
    static var launch: TimeInterval { 1.1 * scale }
    /// Poll cadence for `waitFor…` loops.
    static var poll: TimeInterval { 0.1 * scale }

    static func pause(_ interval: TimeInterval) {
        Thread.sleep(forTimeInterval: interval)
    }
}
