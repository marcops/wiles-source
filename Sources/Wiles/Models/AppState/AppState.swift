import GitBeacon
import Observation
import SwiftUI

/// AppState is @MainActor-isolated (see the annotation below); @unchecked Sendable exists only to
/// satisfy `Task.detached`'s requirement that its `@Sendable` closure's captures conform to
/// Sendable — `self`/`[weak self]` is captured this way throughout this file and
/// AppState+Navigation.swift/AppState+Operations.swift/AppState+ColumnsAndActions.swift. In every
/// one of those closures, `self`'s mutable state is only ever read or written after hopping back
/// via `await MainActor.run { ... }` (or `Task { @MainActor in ... }`) — never directly inside the
/// detached body — so all real mutation stays confined to the main actor.
@Observable
@MainActor
public final class AppState: @unchecked Sendable {
    // MARK: - Domain Stores

    // `var`, not `let`: SwiftUI's `$appState.preferences.someField`-style two-way bindings (used
    // throughout Views/) only compose into a `ReferenceWritableKeyPath` when every intermediate
    // stored property in the chain is mutable — even though `preferences` itself is a class and
    // nothing here actually reassigns it, `let` breaks every such binding across the app.
    public var navigation: NavigationStore
    public var preferences: PreferencesStore
    public var modal: ModalStore
    public var selection: SelectionStore
    public var fileSystem: FileSystemStore
    public var smartFolder: SmartFolderStore
    public var transient: TransientStore
    /// Per-window undo/redo history — each `AppState` (constructed fresh per window) gets its own,
    /// so ⌘Z in one window never undoes an action performed in a different window.
    public let undoRedoService = UndoRedoService()

    /// `nonisolated`: a plain constant URL, safe from any context — lets `FileSystemService`
    /// (off-`@MainActor`) reference it directly instead of duplicating the path as a literal.
    public nonisolated static let recentsVirtualURL = URL(fileURLWithPath: "/virtual/recents")

    public init(preferences: PreferencesStore = PreferencesStore(), modal: ModalStore = ModalStore(), transient: TransientStore = TransientStore()) {
        navigation = NavigationStore()
        self.preferences = preferences
        self.modal = modal
        selection = SelectionStore()
        fileSystem = FileSystemStore()
        smartFolder = SmartFolderStore()
        self.transient = transient

        selection.setSearchQueryHandler { [weak self] in self?.refreshCurrentDirectory() }
        navigation.onVolumeUnreachable = { [weak self] fallback in self?.navigateTo(fallback) }
    }
}
