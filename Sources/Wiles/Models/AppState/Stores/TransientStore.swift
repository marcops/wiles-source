import Foundation
import Observation

/// App-global, in-session state that is never written to `UserDefaults` — resets to defaults on
/// every launch. Distinct from `PreferencesStore` (persisted) and from per-window state (which
/// belongs on `WindowUIState`, not here — see AGENTS.md rule 32).
@Observable
@MainActor
public final class TransientStore {
    public var clipboard: ClipboardState?

    public init() { }
}
