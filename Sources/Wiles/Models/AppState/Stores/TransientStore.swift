import Foundation
import Observation

/// App-global, in-session state that is never written to `UserDefaults` — resets to defaults on
/// every launch. Distinct from `PreferencesStore` (persisted) and from per-window state (which
/// belongs on `WindowUIState`, not here — see AGENTS.md rule 32).
@Observable
@MainActor
public final class TransientStore {
    /// In-flight `~/.Trash` enumeration spawned by `updateTrashSize()`. Cancelled and replaced on every
    /// call so it never piles up multiple concurrent full-Trash walks.
    var trashSizeTask: Task<Void, Never>?
    /// Timestamp of the last trash-size enumeration triggered opportunistically from
    /// `refreshCurrentDirectory()`, used to coalesce it to a coarse interval instead of firing on
    /// every navigation/search keystroke/FSEvents refresh.
    var lastOpportunisticTrashSizeCheck: Date = .distantPast
    static let trashSizeCheckInterval: TimeInterval = 30

    public var clipboard: ClipboardState?

    public var trashSizeString: String = ""
    public var isTrashUpdating: Bool = false

    /// Set while a column-resize drag is in progress so intermediate width updates (which fire on every
    /// mouse-move delta) don't each trigger a synchronous JSON encode + `UserDefaults` write. The final
    /// width is persisted once via `persistColumnWidths()` on drag end. See `ColumnResizeHandle`.
    var suppressColumnStatePersistence: Bool = false

    public init() { }
}
