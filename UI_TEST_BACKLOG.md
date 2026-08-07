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

## Resolved (moved out of this list once tested)

- `AppState.moveSelectedFavorite()` — was on this list, turned out to be plain synchronous state
  logic with no gesture/timing dependency, so it got a real unit test instead
  (`AppStateCoreTests.testMoveSelectedFavorite`). Lesson: check for a real gesture/timing dependency
  before assuming something needs a UI test — most "feels like a UI thing" logic is actually testable.
