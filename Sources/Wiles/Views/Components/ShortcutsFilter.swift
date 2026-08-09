import SwiftUI

/// The three tabs on the shortcuts cheatsheet: the two navigation-mode-specific views (which only
/// show shortcuts that differ between modes with that mode's key), and an "all" view that merges
/// both modes' shortcuts plus app/window-level shortcuts that don't depend on navigation mode.
enum ShortcutsFilter: CaseIterable, Identifiable {
    case windows
    case macOS
    case all

    var id: Self { self }

    var navigationMode: NavigationMode? {
        switch self {
        case .windows: return .gnome
        case .macOS: return .macOS
        case .all: return nil
        }
    }

    var l10nKey: L10n.Key {
        switch self {
        case .windows: return .gnomeModeTitle
        case .macOS: return .macModeTitle
        case .all: return .shortcutsAllTab
        }
    }
}
