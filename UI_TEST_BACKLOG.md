# UI Test Backlog

Behavior changes that are real and correct, but not covered by unit tests today because they need
real gesture simulation, a real stalled network mount, or SwiftUI render-timing infrastructure this
project doesn't have yet (`Tests/WilesUITests` currently drives the compiled app via XCUITest/
accessibility, not synthetic drag gestures or mocked mounts). Per AGENTS.md §28, anything landing
here must be named explicitly at the time it's skipped — not silently dropped.

When XCUITest gains gesture-simulation support (or a mock-mode launch flag gets added to the app),
pull items off this list and write the real test before removing the entry.

## Open items

- **`AppState.navigateTo()` — `/Volumes/` async dispatch branch** (`AppState+Navigation.swift`).
  Needs a real (or simulated-stalled) network/external mount under `/Volumes/` to prove the
  `Task.detached` hop actually keeps `@MainActor` unblocked. A local temp dir can't exercise this
  branch at all (it's gated on the `/Volumes/` path prefix).

- **Grid/List marquee drag-to-select** (`SelectionRectangleOverlay.swift`, used by `FileGridView`/
  `FileListView`). The `DragGesture` handler (rect computation, Cmd-held union-vs-replace, cell-frame
  hit testing) has zero XCUITest coverage — needs a synthetic mouse-drag simulation in
  `WilesUITests`, which nothing in this suite currently does.

- **cellFrames → `SelectionStore` render-optimization fix** (`FileGridView.swift`/`FileListView.swift`/
  `SelectionRectangleOverlay.swift`). The actual claim being fixed — that reading
  `appState.selection.gridCellFrames`/`listCellFrames` only inside the gesture handler (not a view
  `body`) stops FileListView/FileGridView from re-rendering on every newly-visible lazy row during
  scroll — is an `@Observable` view-invalidation behavior. Would need a SwiftUI render-count probe
  (e.g. counting `body` evaluations via a test harness), which this project has no infrastructure for.

- **`ImageThumbnailView` scroll debounce** (100ms `Task.sleep` before starting real QuickLook I/O).
  Needs to simulate a fast scroll fling (rows appearing/disappearing within a frame) and assert the
  debounced rows never call `ThumbnailService.loadThumbnail`. Testable in principle with a mock
  clock/scheduler, but `Task.sleep` here isn't currently injectable.

- **`ThumbnailService.prefetchThumbnails()` cancels the previous run** (zombie-task fix). Tried a
  real-timing test (start a 40-item prefetch, immediately start a 2-item one, assert the first
  stops making progress) — even redesigned as a delta check (compare two samples seconds apart
  instead of a fixed count) it still depends on real `QLThumbnailGenerator` XPC latency, which the
  user explicitly doesn't want given a prior flaky test in this area. Fix shipped on code-review
  confidence instead (`Task.isCancelled` break + `prefetchTask?.cancel()` is a standard, low-risk
  pattern) — manually verify: open a 1,000+ image folder, immediately navigate away, watch Activity
  Monitor CPU drop instead of continuing to churn.
  Note: this project also doesn't unit-test `NSCache.countLimit`/`totalCostLimit` numerically
  anywhere (see `DirectoryCacheService`, which has the same gap) — same call applies to
  `ThumbnailService`'s new limits, for consistency rather than a one-off exception.

- **`FileMetadataService.streamBatchProperties()` stops when the consumer stops** (zombie-task fix,
  same shape as the ThumbnailService one above). The fix wires `continuation.onTermination` to
  cancel the producing `Task` and checks `Task.isCancelled` in the loop — a standard AsyncStream
  cancellation idiom. Proving "the loop actually stopped" without consuming the stream's output
  requires either a real timing wait (rejected, same reasoning as above) or adding test-only
  instrumentation to production code just to make internal loop progress observable, which isn't
  worth the added surface for a one-off test. Shipped on code-review confidence. Currently unused
  by any caller in the app (dead code), so there's no live UI path to manually verify yet either —
  re-check this once something actually calls it.

- **`FileSystemService` N+1 I/O fix — fewer syscalls, not just correct output.** Added
  `.creationDateKey`/`.contentAccessDateKey`/`.effectiveIconKey` to the bulk `contentsOfDirectory`
  prefetch so `FileItem.init`'s own `resourceValues(forKeys:)` call hits a warm cache for them
  instead of a per-file stat/IPC — and dropped the per-file `NSWorkspace.icon(forFile:)` call
  entirely in favor of the same bulk-prefetched icon. Tried to write this red-green: a test
  asserting `dateCreated`/icon come back populated turned out to **pass identically whether the
  prefetch keys are present or not** — `FileItem` already fetched those keys itself as a
  (slower) fallback, so functional output was never wrong, only the number of syscalls behind it.
  Confirmed this by disabling the fix and re-running the test — it still passed, proving it
  can't distinguish fixed from unfixed. Kept the test anyway (renamed honestly in its doc comment)
  since it's still valid *correctness* regression coverage for the refactor, but the actual
  performance claim (fewer syscalls, faster load on a 5,000+ file folder) needs syscall-count
  instrumentation (e.g. `fs_usage`/`dtrace`) or a wall-clock benchmark to verify, neither of which
  this project has. Manually verify: open a folder with thousands of files (e.g. `~/Library/Caches`)
  and compare perceived load time/responsiveness against `git stash` on this change.

- **`PDFMergeService.mergeFiles()` no longer blocks the main thread.** Removed `@MainActor`, moved
  the loop (which calls `NSImage(contentsOf:)`, a synchronous full-bitmap decompression) into
  `Task.detached`, and wrapped each iteration in `autoreleasepool` so large images don't accumulate
  in memory across the whole merge. The functional tests (does it produce a correct merged PDF)
  are covered in `PDFMergeTests`, but "does the UI stay responsive / does memory stay flat while
  merging 50 large images" is a real-world perf/responsiveness claim, not something an XCTest
  assertion can observe (would need an actual UI hang detector or memory-sampling harness this
  project doesn't have). Manually verify: select ~20 large photos (e.g. 50MP RAW/HEIC), "Merge into
  PDF", and confirm the app's UI (spinner, other windows) stays interactive throughout instead of
  beachballing.

- **`SmartFolderService.executeQuery`/`executeContentQuery` observer-token cleanup** on
  `NSMetadataQueryDidFinishGathering`. The predicate-injection half of this fix is unit-tested
  (`SmartFolderServiceTests.testPredicateInjectionIsNeutralized`), but proving the observer token is
  actually removed (no N-fold duplicate firing after N searches) needs a fake/injectable
  `NSMetadataQuery` or a notification-driven test harness — this project has neither. Currently only
  exercised implicitly via manual QA. Manually verify: run several Smart Folder searches back-to-back
  and confirm results/callbacks aren't duplicated.

- **`AutoOrganizationService.processFolder()` cross-volume move `Task.detached` dispatch.** The
  directory-vs-file classification half of this fix is unit-tested
  (`AutoOrganizationTests.testDirectoryEntriesAreNeverMoved`), but proving the move itself actually
  keeps `@MainActor` unblocked during a large cross-volume copy+delete needs a real (or
  simulated-stalled) cross-volume/network mount — a local temp dir move is synchronous-fast and can't
  exercise the stall this fix guards against. Manually verify: configure a rule that moves files to an
  external/different volume, drop a large file in the watched folder, and confirm the UI stays
  responsive while the move completes.

- **`PreferencesStore.scheduleExpandedTreePathsSave()` debounce timing.** The cap-at-500 and
  truncate-on-load halves of this fix are unit-tested
  (`PreferencesStoreTests.testExpandedTreePathsCapsInsertionsAt500`,
  `testExpandedTreePathsTruncatesOnLoadWhenSavedSetExceedsCap`), but proving N rapid expand/collapse
  toggles coalesce into exactly 1 `UserDefaults` write (not N writes) needs a mock clock or injectable
  `DispatchQueue` this project doesn't have. Manually verify: rapidly expand/collapse several folders
  in the directory tree and confirm no UI stutter.

- **`ColumnResizeHandle`'s real `DragGesture`** (`.onChanged`/`.onEnded` wiring, cursor push/pop,
  `dragStartWidth` reset). Only the underlying `AppState.setColumnWidth(_:width:persist:)` contract is
  unit-tested (`AppStateColumnsAndSelectionTests.testSetColumnWidthPersistFlagDefersUserDefaultsWrite`)
  — the actual mouse-drag gesture needs XCUITest simulation. Manually verify: drag a column border and
  confirm smooth resizing with a single persisted write at drag end (not per-pixel).

- **`LocalHttpServerService.stop()`'s `connections` race fix.** Functional correctness (server starts/
  stops/serves correctly) is already covered by `HttpServerTests.swift`. Proving the underlying data
  race is actually eliminated needs a ThreadSanitizer stress test hammering concurrent connections
  during `stop()`, which this project's test infra doesn't support. Manually verify: run the app under
  Thread Sanitizer (Xcode scheme diagnostics), open several simultaneous HTTP-share downloads, and call
  stop mid-transfer repeatedly; confirm no TSan race report on `connections`.

- **`FileColumnView.loadInitialColumns()`'s stale-load guard.** `@State` lives inside a SwiftUI `View`
  struct with no introspection harness in this project; reproducing the race needs a live view
  hierarchy and rapid navigation timing, i.e. XCUITest. Manually verify: rapidly navigate between
  sibling directories in column view (arrow keys / clicks) several times in quick succession and
  confirm the displayed columns always match the final selected URL, never a stale directory's
  contents.

- **`MainContentView.GlobalKeyMonitor.handleScrollEvent`'s accumulated-delta throttling** for
  scroll-wheel icon-size zoom. `handleScrollEvent`/`accumulatedScrollDelta` are `private` inside a
  nested class only reachable via a real `NSEvent.addLocalMonitorForEvents` callback; this project has
  no synthetic-`NSEvent` injection harness. Manually verify: hold Cmd/Ctrl and scroll over the file
  grid — icon size should change in small discrete steps rather than jittering on every tiny scroll
  tick.

- **`DiskSpaceVisualizerSheetView` — mouse wheel / trackpad scroll dead inside the `ScrollView`.**
  Root cause: the `ScrollView` used to only exist in the view tree once the async
  `DiskSpaceVisualizerService.calculateDiskUsage` scan finished (it was inside the
  `isLoading`-vs-`report` conditional branch), so its `NSScrollView` got inserted into the
  already-visible/key sheet window well after initial layout — a known AppKit/SwiftUI interop gap
  where a freshly-inserted `NSScrollView` doesn't reliably wire into the scroll-wheel/trackpad
  responder chain until a resize forces re-layout. Fixed by keeping the `ScrollView` mounted with a
  stable identity from the very first render (only its inner content — loading spinner, empty state,
  or rows — varies with state); the state-machine deciding when the bar chart shows above it is
  covered by `DiskSpaceVisualizerSheetViewTests.shouldShowBarChart`. What's *not* testable here: that
  the real `NSScrollView` actually receives and forwards live `NSEvent.scrollWheel` input, which needs
  a real key window, a real mouse/trackpad event (or synthetic `NSEvent` injection into a mounted
  `NSScrollView`), and this project has no such harness. Manually verify: open Disk Usage Visualizer
  (Shift+Cmd+D) on a folder with >7-8 items so the row list overflows, and confirm both a two-finger
  trackpad swipe and a physical mouse's scroll wheel move the list immediately, with no need to
  resize the window or interact with anything else first.

- **`FileListView` nested-`ScrollView` resize/post-delete scrollbar glitch fix.** User-reported: resizing
  the window sometimes shows both horizontal *and* vertical scrollbars in List View with no content
  reason to need them, and after deleting selected item(s) the row-highlight/scroll geometry looks
  stale until switching to Grid View and back (then re-breaks on the next resize). Root cause: the view
  nested two separate `ScrollView`s (`ScrollView(.vertical) { ScrollView(.horizontal) { ... } }`),
  producing two distinct `NSScrollView`s whose content-size caching/relayout could desync from each
  other on window resize or on an item-count change that isn't a full navigation (`.id()` stays keyed
  on `appState.navigation.currentURL`, which is correct per AGENTS.md §25 — a delete in the same folder
  is not a "wholesale dataset replacement"). Fixed by collapsing to a single
  `ScrollView([.horizontal, .vertical])`, matching the single-`ScrollView` pattern already used by
  `FileGridView`/`FileColumnView`. `selectedURLs`/`SelectionStore` logic itself was independently
  verified correct — `AppStateOperationsExtraTests.testDeleteSelected()` already asserts
  `performDeleteSelected()` clears `selectedURLs`, so the bug was purely AppKit-side scroll-geometry
  caching in the SwiftUI→NSScrollView bridge, not app state. Proving the actual resize-triggered
  double-scrollbar flicker or the post-delete stale-geometry-until-view-switch symptom needs a live
  window resize + real `NSScrollView` introspection (scroller visibility, content size) under XCUITest,
  which this project's test infra doesn't drive today. Manually verify: open a folder with enough items
  to scroll vertically but not so many columns as to need horizontal scroll, resize the window
  repeatedly (including narrower than the content), and confirm only the scrollbar(s) actually needed
  appear; then select and delete an item and confirm the list reflows immediately without needing a
  Grid-View round-trip.

- **`AppState.deleteSelected()` — `preferences.skipDeleteConfirmation` bypass branch**
  (`AppState+Operations.swift`). This one IS plain synchronous state logic (no gesture/timing
  dependency) and would normally get a same-round unit test per rule 28 — e.g. "POS: with
  `skipDeleteConfirmation = true` and a non-empty selection, `deleteSelected()` calls
  `performDeleteSelected()` directly and never sets `showDeleteConfirmAlert`" / "NEG: with
  `skipDeleteConfirmation = false`, `deleteSelected()` sets `showDeleteConfirmAlert = true` and does
  not touch the file system." Deferred this round at the user's explicit request so the behavior can
  be manually reviewed first — pull this off the list and write the real test (modeled on the
  existing `AppStateOperationsTests.swift` suite) before the next round touching this file.

- **Settings window (`SettingsView.swift` + per-tab views under `Sources/Wiles/Views/Settings/`)**.
  A `Settings` scene (`WindowGroup`-adjacent `Settings { ... }`) has no XCTest-observable window
  identity today, and its content is a `TabView` of `Form`/`Toggle`/`Picker` bindings straight into
  `PreferencesStore` — the individual bindings are exercised indirectly by the existing
  `PreferencesStoreTests`/`AppStateOperationsTests` coverage of the underlying properties, but the
  view wiring itself (right control bound to right key, tab layout, `⌘,` opens it) needs a real
  window + accessibility query, i.e. `Tests/WilesUITests`. Manually verify: `⌘,` opens Settings,
  every toggle/picker matches the equivalent old menu item's prior behavior, and toggling something
  in Settings updates the live UI (e.g. toggling "Show Hidden Files" in Settings immediately reflects
  in the file list) without needing to close the window.

- **`CommandGroup(replacing: .newItem)` "New Wiles Window" translation** and
  **`CommandGroup(replacing: .saveItem)` "Close" translation** (`WilesApp.swift`). These replace
  SwiftUI/AppKit's own auto-generated File-menu commands (previously untranslated, always following
  the OS locale instead of `appState.preferences.appLanguage`) with `appState.tr(.newWindow)` /
  `appState.tr(.close)`. Whether the system's default items are actually fully suppressed (no
  duplicate "New Window"/"Close" entries) and whether `⌘N` still opens a genuinely new window via
  `openWindow()` can only be confirmed by opening the real running app's File menu — `swift build`
  alone can't prove menu-bar contents. Manually verify: switch the in-app language picker to
  Portuguese (or any non-English locale) and confirm every File-menu item, including "Novo Wiles
  Janela"/"Fechar", is translated with no leftover English "New Window"/"Close" and no duplicate
  entries.

- **`ShortcutsHUDOverlay` — full rework across several rounds** (mode-preview tabs, Escape-to-close,
  header/footer restructure, subtitle, spacing). Current state, superseding the earlier note in this
  file (which described an already-reverted `.onExitCommand`/X-button approach):
  - Added a GNOME/Win vs macOS mode-preview tab row, centered per rule 31, with a "CURRENT" badge on
    whichever tab matches `appState.navigationMode`.
  - Escape-to-close is wired via an invisible `Button("").keyboardShortcut(.escape,
    modifiers: []).hidden()` inside the overlay (NOT `.onExitCommand`, which silently never fires here
    since this overlay is a manual `ZStack`, not a real `.sheet`, and never establishes keyboard
    focus — see rule 30). `MainContentView`'s own global hidden Escape button (deselect-all) is
    `.disabled(appState.showShortcutsHUD)` so it doesn't win the conflict.
  - Header X button removed; closing happens only via the footer's right-aligned "Done" button
    (`.keyboardShortcut(.defaultAction)`) or Escape, per rule 30.
  - Header now has a subtitle line under the title (`shortcutsCheatsheetSubtitle`), per rule 30's
    header convention.
  - Structural `Divider()`s added between header/tabs, content, and footer; the redundant per-group
    divider that used to sit after every `shortcutGroup`'s last row was removed (rule 31: don't stack
    dividers).
  - Content padding is asymmetric (more on the leading edge than trailing) so keycap badges sit close
    to the true trailing edge instead of being centered with dead space, per rule 31.
  - Needs a unit test for the escape/close state transition (plain `appState.showShortcutsHUD` toggle
    logic — testable) and a UI test for the actual physical Escape key dismissing it, the mode tabs
    updating the shown shortcut list, and the "CURRENT" badge tracking Settings → General's Shortcut
    Mode (all need a real view hierarchy / XCUITest key-event simulation). Manually verify: open the
    cheatsheet (⌘/), press Escape (confirm it closes), reopen, click "Done" (confirm it closes), click
    both mode tabs and confirm the shortcut list + badge update correctly, and confirm text isn't
    glued to the left edge and the scrollbar sits near the right edge.

- **`FolderPickerSheet` (new, `Views/Modals/FolderPickerSheet.swift`) replacing `NSOpenPanel` in
  `AutoOrganizationSheet`'s source/destination folder pickers.** User-reported: picking a folder for an
  Auto-Organization rule opened the system's native `NSOpenPanel` (visually indistinguishable from
  Finder to the user) instead of an in-app picker. Replaced with a self-contained tree browser built on
  the existing `FolderNode` model (own local `@State` for selection/expansion, deliberately NOT reusing
  `DirectoryTreeNodeView` since that one calls `appState.navigateTo()` directly and would have hijacked
  the main window's navigation as a side effect of picking a folder in a modal). Needs both a unit test
  (does `FolderPickerSheet`'s `expandAncestors(of:)` correctly expand every parent path component — pure
  logic, testable) and a UI test (does clicking a row actually select it, does double-clicking or
  pressing the "Select Folder" button correctly call the `onSelect` closure with the right URL — needs a
  real view hierarchy). Manually verify: Tools → Auto Organization → click a folder button for either
  "If file in" or "Move to", confirm the new in-app tree picker opens (not a system panel), that
  Home/Desktop/Documents/Downloads quick-links work, that selecting a nested folder and clicking
  "Select Folder" correctly fills in the button label.

- **`DefaultFolderHandlerService.registerAsFolderHandlerOption()` (new) + `CFBundleDocumentTypes` for
  `public.folder` in Info.plist (`Settings → Advanced`).** Important caveat surfaced to the user directly
  in the Settings UI copy: macOS reserves double-click-to-open for a folder exclusively to Finder — there
  is no public API for any third-party app to override that system-wide, and this has been true for the
  entire history of macOS (every Finder-alternative app, e.g. ForkLift/Path Finder, hits this same wall).
  What IS achievable and implemented here: registering Wiles via `NSWorkspace.setDefaultApplication(at:
  toOpen: .folder)` plus declaring `public.folder` as an "Alternate"-rank `CFBundleTypeRole: Viewer` in
  `CFBundleDocumentTypes`, which makes Wiles appear as a choice in Finder's right-click → "Open With"
  submenu for folders. Needs a UI test (does the Settings button actually show the success/failure
  string) — the underlying `NSWorkspace` call itself can't be meaningfully unit-tested (it talks to real
  LaunchServices state on the test-running machine, which would pollute the developer's actual system
  configuration). Manually verify: Settings → Advanced → "Register Wiles for Folders", confirm a
  confirmation message appears, then right-click any folder in Finder and confirm "Wiles" now appears in
  the "Open With" submenu (double-clicking the folder itself will still correctly open Finder, per the
  OS limitation above — that's expected, not a bug).

- **Multi-window: `appState` is shared by every window, so every sheet/overlay toggle (shortcuts
  HUD, New Folder, Properties, Auto Organization, Help, About, etc.) shows in every open window at
  once.** History, so the next attempt doesn't repeat either failure:
  1. First attempt: made "New Window" bring the existing window forward instead of calling
     `openWindow`. Broke the feature entirely — at least one window always exists while the app
     runs, so `openWindow` could never fire and clicking "New Window" did nothing visible.
  2. Second attempt: reverted (1), and instead moved just `showShortcutsHUD` off `AppState` into a
     local `@State` in `MainContentView`, published per-window to the App-level `Commands` via
     `.focusedValue(\.shortcutsHUDBinding, ...)` / `@FocusedValue` in `WilesApp`. Broke the shortcut
     entirely — `.focusedValue` (the non-scene variant) only propagates while something in that view
     hierarchy actually holds SwiftUI's native keyboard focus, and this app doesn't use SwiftUI's
     focus system (everything is custom `NSEvent` monitors), so the value was always `nil` and the
     toggle silently no-opped. (`.focusedSceneValue` — the scene-scoped variant, tied to which window
     is the active scene rather than to keyboard focus — is the one that should actually work here,
     untried yet.)
  3. **Reverted back to the simple pre-existing behavior**: `showShortcutsHUD` restored to
     `AppState`, "New Window" restored to unconditionally calling `openWindow(id:)`. Known
     limitation, not silently broken: opening a second window means the shortcuts HUD (and every
     other sheet) shows in both windows.
  Next attempt should: (a) use `.focusedSceneValue` instead of `.focusedValue`, and (b) do it for
  every affected sheet/overlay flag at once (ideally via one shared per-window presentation-state
  object exposed through a single `@FocusedValue`, not one binding per flag) rather than one flag at
  a time. Needs a UI test once implemented (open two windows, toggle something in one, confirm the
  other window is unaffected) — this is window-focus/AppKit behavior with no unit-testable pure-logic
  component. Manually verify current (reverted) behavior: `⌘N` opens a second window; toggling the
  shortcuts cheatsheet (or any sheet) in either window shows it in both — expected today, not a bug.

- **`AutoOrganizationSheet` header subtitle** (`autoOrganizationSubtitle` key, all 15 locales) added
  per rule 30's header convention (title + secondary description line). Purely a static string
  addition wired into an existing header `VStack` — no new logic, nothing to unit-test. Also fixed:
  the `autoOrganization` title key itself was left as untranslated English placeholder text in 10 of
  15 locales (ar/it/ko/pl/ja/nl/tr/sv/ru/zh-Hans) despite `pt`/`es`/`de`/`fr` already being translated
  — a pre-existing gap unrelated to this session's changes, fixed while touching the same string.
  Manually verify: Tools → Auto Organization, confirm the subtitle appears under the title, and check
  the title text in a couple of the previously-untranslated locales via Settings → General → Language.

- **Menu bar icons** on Settings (`gearshape`), View Mode (`square.grid.2x2`), and Sort By
  (`arrow.up.arrow.down`) in `WilesApp.swift` — changed from plain `Button`/`Picker`/`Menu` string
  labels to `Label(title, systemImage:)`. Purely declarative SwiftUI, nothing to unit-test. Manually
  verify: open the app menu and View menu, confirm all three items show an icon consistent with the
  rest of the menu bar's existing icon usage.

- **Settings/Preferences terminology consistency fix** across `ar`/`es`/`it`/`nl`/`pl`/`pt`
  (`settingsMenuItem`, `settingsWindowTitle`). English and most other locales already use the
  post-Ventura "Settings" term; these six were still using the pre-2022 "Preferences"-style word for
  the same concept — updated to match (e.g. `pt`: "Preferências" → "Ajustes", `es`: "Preferencias" →
  "Ajustes", `it`: "Preferenze" → "Impostazioni"). Pure string-content fix — nothing to unit-test
  beyond what an eventual "every L10n key exists in every locale" audit already covers structurally
  (existence, not semantic correctness). Manually verify: switch language to each of the six locales
  in Settings → General and confirm the Settings menu item / window title use the modern term.

- **`ShortcutsHUDOverlay` — two rendering fixes to the card background.**
  1. Consolidated per-layer `.cornerRadius(16)` calls (one on `TranslucentVisualEffectView`, an
     implicit one via the `RoundedRectangle` fill) into a single `.clipShape(RoundedRectangle
     (cornerRadius: 16))` applied once to the fully-composited card — mismatched per-layer corner
     clipping was causing the rounded top area (where the header sits) to render inconsistently
     against the rest of the card.
  2. The dimming backdrop (`Color.black.opacity(0.3)`) didn't have `.ignoresSafeArea(.all, edges:
     .top)`, unlike `MainContentView`'s content stack — so the strip where `HeaderBarView` extends
     into the hidden-title-bar region at the very top of the window stayed undimmed while everything
     below it darkened normally. Added the same `.ignoresSafeArea` to the backdrop.
  Both are pure rendering/layering fixes with no unit-testable logic component. Manually verify: open
  the shortcuts cheatsheet (⌘/) and confirm (a) the header's background shade matches the rest of the
  card with no visible seam, and (b) the dimming backdrop covers the main window's top toolbar strip
  (traffic lights/breadcrumb/search) exactly as evenly as it covers the sidebar and file list below it.

- **`WindowUIState` — per-window scoping for every sheet/alert/HUD** (new file
  `WindowUIState.swift`; touches `MainContentView.swift`, `WilesApp.swift`,
  `SharedViewHelpers.swift`, `SidebarView.swift`, `DirectoryTreeNodeView.swift`,
  `PreviewSidebarView.swift`, `HeaderBarView.swift`, `NewFileSheetView.swift`,
  `PasswordCompressSheetView.swift`, `AppState.swift`, `AppState+Operations.swift`,
  `ModalStore.swift`). Fixed the bug class where, with multiple Wiles windows open, any
  window-scoped sheet/alert/HUD (Properties, New Folder, New File, Batch Rename, Disk Usage, Connect
  to Server, Auto Organization, Share via Wi-Fi, Save Smart Folder, Compress with Password, Archive
  Inspection, Rename, Image Converter, Create Symlink, Empty Trash confirm, Move to Trash confirm,
  Help, About, and the shortcuts HUD) opened in *every* open window at once instead of just the one
  the user acted on. All of these moved off the window-shared `AppState`/`ModalStore` onto a new
  per-window `WindowUIState` (`@Observable`, instantiated as `@State` in `MainContentView`), injected
  into that window's view tree via `.environment(_:)` and read by descendants with
  `@Environment(WindowUIState.self)`; published to the app-level menu `Commands` (which sit outside
  any single window's view hierarchy) via `.focusedSceneValue`/`@FocusedValue`. `AppState.deleteSelected()`
  and `.openPropertiesForSelected()` now take a `windowUIState:` parameter since the confirm-alert/
  properties-item they set is window-scoped. `ModalStore.showErrorAlert`/`errorMessage` intentionally
  stayed on the shared `AppState` — background-originated errors (auto-organization, network ops)
  have no owning window and must surface regardless of focus (see AGENTS.md rule 32 for the general
  pattern, captured there for future features). Needs multi-window XCUITest infrastructure to assert
  "sheet/alert X visible in window A, not in window B" — `Tests/WilesUITests` currently drives a
  single window. Manually verify: open two windows (⌘N), and for each of the presentations listed
  above, trigger it from one window (menu item, ⌘-shortcut, or context menu) and confirm it appears
  only in that window, while the other window's own trigger still opens/closes its own instance
  independently.

- **Shortcuts HUD "All Shortcuts" tab + renamed Windows/Mac tabs + Help menu relocation**
  (`ShortcutsHUDOverlay.swift`, `HelpSheet.swift`, `WilesApp.swift`, `NavigationMode.swift`,
  `LocalizationService.swift` + all 15 `Localizable.strings`). Three changes bundled together:
  1. `NavigationMode.gnome`'s user-facing label changed from "GNOME Mode" to "Windows Mode"
     everywhere (Settings picker, shortcuts HUD tab) — the enum case name, its persisted
     `UserDefaults` raw value, and `l10nKey`/`gnomeModeTitle` identifiers were deliberately left
     unchanged to avoid resetting existing users' saved navigation-mode preference; only the
     translated string content changed.
  2. Added a third "All Shortcuts" tab (`ShortcutsFilter.all`) to the HUD that merges the
     Windows-mode and macOS-mode variants of Navigation/File Actions/System (`merged(_:_:)`
     collapses identical bindings, labels differing ones "X (Mac) · Y (Windows)"), plus a new
     "General" group for app/window-level shortcuts that were previously only listed in the Help
     sheet's removed shortcuts tab (Settings, New Window, Close, Open, Toggle Terminal, Toggle
     Preview, Go to Folder, Connect to Server, Disk Usage Visualizer, Wiles Help). Two stale entries
     from the old Help list were dropped rather than carried over: "Refresh Directory (⌘R)" (no such
     shortcut is actually wired anywhere in `WilesApp.swift`) and "Toggle Status Bar (⌘/)" (⌘/ is
     actually the shortcuts-HUD toggle, mislabeled in the old list).
  3. Removed the redundant shortcuts list from `HelpSheet.swift` (`HelpTab.shortcuts` case,
     `shortcutsSection`, `shortcutRow`) since the HUD now fully supersedes it. Consolidated the
     "open shortcuts HUD" command into the Help menu only (previously duplicated across the View
     menu and the Tools menu) via `CommandGroup(replacing: .help)`.
  No behavior here has a testable logic component beyond string/UI content — `merged(_:_:)` is a
  pure function and could get a real unit test (compare two hand-built `[(String,String)]` arrays,
  assert collapse vs. combine), but wasn't added yet per project convention (tests written after
  manual review, not alongside the UI change). Manually verify: open the shortcuts HUD (⌘/, now only
  in the Help menu — confirm it's gone from View and Tools menus), confirm three tabs read "Windows
  Mode (Default)" / "macOS Finder Mode" / "All Shortcuts", confirm the current mode's tab shows the
  "Current" badge, confirm the All tab shows merged Mac/Windows bindings plus the General group, and
  confirm Settings' navigation-mode picker also now reads "Windows Mode (Default)". Also confirm the
  Help sheet (separate ⌘? item, still in Help menu) no longer has a Shortcuts tab.

## Resolved (moved out of this list once tested)

- `AppState.moveSelectedFavorite()` — was on this list, turned out to be plain synchronous state
  logic with no gesture/timing dependency, so it got a real unit test instead
  (`AppStateCoreTests.testMoveSelectedFavorite`). Lesson: check for a real gesture/timing dependency
  before assuming something needs a UI test — most "feels like a UI thing" logic is actually testable.
