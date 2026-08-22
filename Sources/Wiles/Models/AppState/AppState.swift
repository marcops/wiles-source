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

    // MARK: - Operational State

    public static let recentsVirtualURL = URL(fileURLWithPath: "/virtual/recents")

    public init(preferences: PreferencesStore = PreferencesStore(), modal: ModalStore = ModalStore(), transient: TransientStore = TransientStore()) {
        navigation = NavigationStore()
        self.preferences = preferences
        self.modal = modal
        selection = SelectionStore()
        fileSystem = FileSystemStore()
        smartFolder = SmartFolderStore()
        self.transient = transient

        selection.onSearchQueryChanged = { [weak self] in self?.refreshCurrentDirectory() }

        updateTrashSize()
    }
}
