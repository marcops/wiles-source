import Foundation

/// Deliberate delays before dispatching UI/process work back onto the main queue, so the
/// downstream action lands on a stable target (a ready shell process, a settled animation)
/// instead of racing it.
public enum AsyncDelayTokens {
    /// Wait for the embedded terminal's shell process to finish starting before sending the
    /// initial `cd`/`clear` commands.
    public static let terminalInitialCommandDelay: TimeInterval = 0.5

    /// Wait for the search field's reveal animation to settle before requesting keyboard
    /// focus, so focus isn't stolen mid-animation.
    public static let searchFieldFocusDelay: TimeInterval = 0.05

    /// Wait for the path bar's expand animation to settle before scrolling to the end, so the
    /// target offset is computed against the final (not still-animating) content width.
    public static let pathBarScrollDelay: TimeInterval = 0.16
}
