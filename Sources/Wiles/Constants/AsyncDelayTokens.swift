import Foundation

/// Deliberate delays before dispatching UI/process work back onto the main queue, so the
/// downstream action lands on a stable target (a ready shell process, a settled animation)
/// instead of racing it.
public enum AsyncDelayTokens {
    /// Wait for the embedded terminal's shell process to finish starting before sending the
    /// initial `cd`/`clear` commands.
    public static let terminalInitialCommandDelay: Duration = .milliseconds(500)

    /// Wait for the search field's reveal animation to settle before requesting keyboard
    /// focus, so focus isn't stolen mid-animation.
    public static let searchFieldFocusDelay: Duration = .milliseconds(50)

    /// Wait for the path bar's expand animation to settle before scrolling to the end, so the
    /// target offset is computed against the final (not still-animating) content width.
    public static let pathBarScrollDelay: Duration = .milliseconds(160)

    /// How long a name label stays selected before un-truncating in place — matches selecting
    /// an item and pausing on it, without popping open on every quick click-through.
    public static let nameRevealDelay: Duration = .seconds(3)

    /// Wait before spring-loading into a hovered folder during a drag, so a drag that merely
    /// passes over the folder doesn't trigger navigation.
    public static let springLoadedFolderDelay: Duration = .milliseconds(750)

    /// Finder-style "click, pause, click again" delay before treating a click on an
    /// already-selected item as a rename request, distinct from a fast double-click that opens it.
    public static let renameDelay: Duration = .milliseconds(400)

    /// Debounce before starting thumbnail I/O for a newly visible row — during a fast scroll
    /// fling, rows appear and disappear within a frame or two, so waiting a beat means a row
    /// that's only ever transiently visible never costs any CPU.
    public static let scrollSettleDebounce: Duration = .milliseconds(100)
}
