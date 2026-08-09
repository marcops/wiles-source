# UI Test Backlog

Behavior changes that aren't practically unit-testable with the project's current test
infrastructure (no XCUITest gesture simulation, no SwiftUI render-timing harness for transitions).
Logged per rule 28 in `.agents/AGENTS.md` instead of silently skipped. Pull an item off this list
and write the real test the moment the missing infrastructure exists.

## `FileColumnView.refreshAllColumnsFromDisk()` — Column view refresh on delete
- **File**: `Sources/Wiles/Views/Content/FileColumnView.swift`
- **What's missing**: The method is a private helper on a SwiftUI `View` struct, driven by
  `@State private var columns` and an `.onChange(of: appState.fileSystem.items)` hook. There's no
  protocol seam to inject a fake `FileSystemService` or observe `columns` from a test — reaching it
  requires either exposing internal view state (which would leak SwiftUI concerns into a plain unit
  test) or a real rendered view hierarchy with a working `.onChange` pipeline, which this project's
  test target doesn't drive.
- **What it needs**: A render-timing harness (or restructuring the column data model behind a
  testable, non-View-owned store) capable of asserting that deleting a file inside a drilled-in
  (non-root) column removes it from that column's displayed items.

## `FileItemInteractionsModifier` — consolidated drag/select/double-click/spring-load gestures
- **File**: `Sources/Wiles/Views/Components/FileItemInteractionsModifier.swift`
- **What's missing**: `onTapGesture(count: 2)`, `simultaneousGesture(TapGesture())`, `.onDrag`, and
  `RightClickDetector` all require real AppKit event delivery to fire — there's no way to simulate a
  double-click, single-click, or drag gesture against a `ViewModifier` in the current XCTest target.
- **What it needs**: XCUITest coverage (`Tests/WilesUITests/`) driving double-click-to-open,
  single-click-select, drag-and-drop, and right-click-context-menu against List, Grid, and Column
  views specifically, since this modifier consolidation (previously `FileRowInteractionsModifier` +
  inline gesture code duplicated per-view) is exactly the kind of change rule 28 flags as needing
  verification that behavior didn't drift across the three views.

## `MainContentView` — delete-confirmation alert default button
- **File**: `Sources/Wiles/Views/Content/MainContentView.swift`
- **What's missing**: `.keyboardShortcut(.defaultAction)` on the "Move to Trash"/"Empty Trash" alert
  buttons changes which button responds to Return — this is an AppKit `NSAlert` default-button
  routing behavior, not observable from a unit test without a live alert on screen.
- **What it needs**: An XCUITest that opens the delete confirmation, presses Return, and asserts the
  file was moved to Trash (not opened/renamed).

## `InlineRenameField` — direct-in-view rename (replaces the old `RenameSheetView` modal)
- **File**: `Sources/Wiles/Views/Components/InlineRenameField.swift`, wired into
  `FileGridCardItemView`/`FileListView`/`FileColumnRowView` via `windowUIState.renameItem`.
- **What's missing**: Needs a focused `TextField` receiving real keyboard input (typed text, Return
  to commit, Escape to cancel, newline-stripping on paste) and focus-loss-commits-on-click-away —
  none of that is reachable without real AppKit event delivery/focus, same class of gap as
  `FileItemInteractionsModifier` above.
- **What it needs**: XCUITest coverage per view (Grid/List/Column): trigger rename, type a new name,
  commit via Return — assert the file was actually renamed on disk; trigger rename, press Escape —
  assert the original name is unchanged; verify clicking away from the field also commits.

## `AppState` and `AppState+*` extensions / `Stores/NavigationStore.swift` — deliberately deferred
- **Files**: `Sources/Wiles/Models/AppState/AppState.swift`, `AppState+ColumnsAndActions.swift`,
  `AppState+Selection.swift`, `AppState+Operations.swift`, `AppState+Navigation.swift`, and
  `Sources/Wiles/Models/AppState/Stores/NavigationStore.swift`.
- **Why this is here**: not a "not unit-testable" gap like the rest of this file — a prior audit
  flagged these as missing dedicated 1-to-1 test coverage, but the project maintainer has a standing
  preference to hold off writing `AppState`/`NavigationStore` tests until the underlying behavior has
  been manually reviewed first (see the "Wiles defer tests until reviewed" project note). Logged here
  instead of silently skipped, per the same rule 28 discipline as the rest of this backlog.
- **What it needs**: once manually reviewed, dedicated test files following the existing
  `Tests/WilesTests/Models/AppState/AppState*Tests.swift` / `Stores/*StoreTests.swift` pattern -
  `NavigationStore.swift` in particular has no `NavigationStoreTests.swift` counterpart yet, unlike
  `FileSystemStore`, `ModalStore`, `PreferencesStore`, and `SelectionStore`, which already do.

## List/Grid smooth row-removal animation
- **Files**: `Sources/Wiles/Views/Content/FileListView.swift`, `Sources/Wiles/Views/Content/FileGridView.swift`
- **What's missing**: The Finder-style "remaining rows slide up" effect is driven by
  `.transition(.opacity)` + `.animation(_:value:)` on the row `ForEach` — SwiftUI transitions/
  animations aren't observable via a snapshot-free unit test; verifying it requires either a visual
  snapshot test or manual QA.
- **What it needs**: Manual verification (delete 1 of several items in List and Grid, confirm the
  remaining rows animate into place) until this project has snapshot/animation-timing test infra.
