import Foundation
import Observation

/// Transient, in-session state for the currently-running smart folder — same category as
/// `SelectionStore` (cell frames, anchors), not `PreferencesStore`. Nothing here is written to
/// `UserDefaults`; it's runtime-only and resets to defaults on every launch.
@Observable
@MainActor
public final class SmartFolderStore {
    /// Which smart folder (if any) is the one currently shown — drives the sidebar's active
    /// highlight on that row, since `navigation.currentURL` doesn't move for a smart folder run and
    /// so can't be used to compute it the way a normal folder's highlight is.
    public var activeFolderID: SmartFolder.ID?

    /// Set for one search-field appearance to skip its usual auto-focus-on-appear — a smart folder
    /// run shows the search bar (to display its query) but the user's next action is clicking a
    /// result, not typing more. Auto-focusing the field anyway meant that first click just resigned
    /// the field's focus instead of reaching the grid item underneath, so it silently did nothing.
    public var suppressNextSearchFocus = false

    /// `true` when the last run's Spotlight gather timed out (the scope is on an unindexed volume),
    /// so the empty-results view can say results may be incomplete rather than "no matches".
    public var lastRunTimedOut = false

    public init() { }
}
