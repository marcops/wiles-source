I want a review dedicated exclusively to RENDERING/VISUAL bugs — not
architecture, not business logic, not data concurrency. `eval.md` already
covers that. This document exists because `eval.md` alone has demonstrably
NOT caught an entire class of bug: code whose LOGIC is correct but whose
visual effect on screen is wrong (e.g., a sidebar scrollbar that never
appears after the directory tree is expanded — a recursive `LazyVStack`
nested inside a single shared ancestor `ScrollView`, breaking the
`NSScrollView`'s geometry recalculation).

Reason for having a separate document instead of just another section in
`eval.md`: an architecture review reads the code and asks "is the logic
right?". A rendering review reads the code and asks a fundamentally
different question — "when THIS value changes, what EXACTLY recalculates on
screen, and WHEN?" — and a good part of the findings here can only be
CONFIRMED by actually running the app (`scripts/run_ui_test.sh`, which
drives the app through the Accessibility API), not just by reading text.
The two lenses require different checklists and methodology; mixing them
turns the rendering lens into a forgotten item buried inside a 900-line
list about something else.

## Scope

- Every file in `Sources/Wiles/Views/**/*.swift`.
- Every `NSViewRepresentable`/`NSViewControllerRepresentable` in any folder
  (e.g., `ScrollerAutoHideSetter`, `SplitViewDividerSetter`,
  `TranslucentVisualEffectView`).
- Every custom `ViewModifier` that affects appearance/scroll/animation
  (`.translucentBackground`, `.resetPaginationAndPrefetchThumbnails`, etc.).
- Any `@State`/`@Binding`/`@Observable` property that directly feeds one of
  these files, even if the property itself lives in `Models/AppState/`.
- Do NOT review business logic, filesystem, data concurrency, or
  persistence here — that's `eval.md`. If a finding is really about logic
  (not about what appears on screen), record it for `eval.md` instead of
  forcing it in here.

## Watchers / Recurring Events (TEMPORARY — belongs in `eval.md`, not a render bug)

Rule parked here at the user's request; move it to the "High-Frequency
Events" section of `eval.md` when there's an opportunity. It's not in scope
for this document (it's logic/concurrency, not rendering) — recorded here
only so it doesn't get lost.

Motivation: a real bug (sidebar/main content stuck "loading" forever) went
through several rounds of `eval.md` without being caught. The
"High-Frequency Events" section already existed and already named the
right pattern ("watchers", "coalescing", "stale events processed when the
result is no longer relevant"), but the finding was discarded because the
evidence ("the load takes longer than the interval between events") seemed
to depend on a runtime condition not demonstrable in the code — exactly the
kind of thing "Evidence and Confidence" downgrades to MEDIUM/LOW
confidence, which the ROI filter then discards.

New rule: promote to CONFIRMED (no runtime repro needed) every case where
ALL of the conditions below are verifiable by reading the code:

1. There's a recurring, external event source (FSEvents/watcher,
   `NSNotification`, timer, network message) that triggers a
   refresh/reload function.
2. That function does a cancel-and-restart of the previous operation
   (`task?.cancel()` followed by a new `Task { }`) instead of letting the
   in-flight operation finish.
3. The cost of the cancelled operation scales with an external factor with
   no known upper bound (file count, network response size, etc.) — i.e.,
   there's no guarantee it will always finish faster than the interval
   between events.
4. There is no mechanism, on the event's CONSUMER side (not the producer),
   that only lets a new attempt replace the previous one if the previous
   one has already finished (a debounce/coalescing on the event PRODUCER
   side alone doesn't count — it limits the firing rate, but doesn't stop
   the next firing from cancelling work still in progress).

When all 4 conditions hold, this is a structural livelock — not a
hypothesis — even without a real large/noisy folder on hand to reproduce
it. The case confirmed in this project: `DirectoryMonitor` (FSEvents) →
`AppState.startDirectoryMonitoring`'s callback → `refreshCurrentDirectory`
→ `fileSystem.refreshTask?.cancel()` + a new `Task`, with the cost of
`FileItem.load`/`resolveHighResIcon` scaling with the number of files in
the folder. Fixed with an `isRefreshing` flag on the consumer: an event
that arrives while a refresh is already running is dropped (not
cancelled), guaranteeing that at least one attempt always runs to
completion. Regression test:
`AppStateDirectoryRefreshTests.testDirectoryListingCompletesUnderContinuousExternalWritePressure`.

## What to look for

For each View, explicitly trace:

`Value/state that changes → who observes that value → what specifically
recalculates on screen → WHEN it recalculates (same frame? next layout
pass? only on a full remount?) → is the final visual result correct?`

This is the "rendering desk check": it's not enough to confirm the data
changed — you have to confirm the RIGHT widget, at the right time, reacted
to that change. Correct data with a widget that doesn't recalculate at the
right time produces exactly the kind of bug a logic review never sees.

### Statically recognizable red-flag patterns

These are verifiable by reading the code, without needing to run the app —
treat them as automatic suspects, not proof of a bug:

- **Recursive `LazyVStack`/`LazyHStack`**: a View that self-references
  (`Self(...)`) and uses `LazyVStack` internally, nesting multiple
  instances inside ONE shared ancestor `ScrollView`. Each level of
  recursion is a bet that the `ScrollView` will correctly recalculate the
  total size when a deep level changes size — often it doesn't. Prefer a
  plain `VStack` in this pattern, unless the number of items per level is
  genuinely large (hundreds+).
- **Async content arriving after the initial layout** (`.task`, `Task {}`,
  callback) that writes to `@State`/a cache consumed by a
  `ScrollView`/`Lazy*Stack`. Ask: does the parent container recalculate its
  size when this arrives, or only on the View's next full remount?
- **An `NSViewRepresentable` that locates a specific `NSView` by walking
  the hierarchy** (`superview`/`subviews`) to style it — e.g., forcing
  `scrollerStyle`, finding the real `NSScrollView` underneath a SwiftUI
  `ScrollView`. Never take the code's own comment as proof that it works;
  this is code that's not statically verifiable by definition. A
  `hasApplied`-style gate that never reapplies after the hierarchy changes
  size is a concrete sign the found instance can go stale as soon as the
  content grows.
- **An appearance modifier applied at the wrong level of the tree**
  (`.scrollIndicators`, `.animation`, `.clipShape`, `.mask`,
  `.background`) — compare where the code's comment says the effect should
  appear versus exactly which View the modifier is attached to.
  `.background()` in particular creates ambiguity about whether the
  resulting View is a SIBLING of the actual content or ends up NESTED
  inside it — the difference completely changes which AppKit hierarchy
  results from it.
- **A `GeometryReader`/`ScrollViewReader` proxy used after the value that
  originated that frame has already changed** — proxies captured in async
  closures can be stale by the time they're used.
- **Local `@State` vs. a shared reference (`class`) used as a "cache"
  behind several Views** — if one is `@State` (SwiftUI observes it) and
  the other is a plain shared reference (SwiftUI doesn't observe it),
  which one actually triggers the re-render matters exactly for WHERE and
  WHEN the screen updates. See `BoundedFolderNodeCache`'s doc comment for
  the case already fixed in this project.
- **`.id()` changing the View's identity** — forces a full remount (loses
  `@State`, resets scroll position, resets any in-flight animation). Check
  whether this is intentional or an unnoticed side effect.
- **An AppKit `NSView`/`NSScrollView` property set only ONCE (a
  `hasApplied`/`hasAppliedStyle`-style gate), when that property is one
  that AppKit ITSELF also reassigns at runtime on its own** — e.g.,
  `NSScrollView.scrollerStyle`, which macOS recalculates on its own based
  on the input device (physical mouse vs. trackpad) under "Show scroll
  bars: Automatically based on mouse or trackpad", **with no notice to the
  app whatsoever**. Code that forces this value once on mount and never
  reinforces it again is in a race against AppKit itself — whoever "wins"
  last (the app, on mount, or the system, on any future scroll) decides
  the behavior, and the system always wins after the first real scroll.
  This doesn't show up as `isHidden == true` or as any kind of error — the
  `NSScroller` still exists and is "not hidden" as far as AppKit itself is
  concerned, it just gets drawn behind the content (which didn't make room
  for the `.legacy` style that replaced `.overlay`). Case confirmed in
  this project: `ScrollerAutoHideSetter` forced `scrollerStyle = .overlay`
  only once; a real mouse wheel made macOS switch to `.legacy`, and it
  never went back — not even by switching to other sidebar sections.
  Fixed by reinforcing the value on EVERY call (`layout()`/`updateNSView`)
  and also directly in the
  `NSScrollView.willStartLiveScrollNotification`/`didLiveScrollNotification`/`didEndLiveScrollNotification`
  observers (the View's own `layout()`/`updateNSView` doesn't necessarily
  fire during a pure scroll gesture). Regression test:
  `ScrollerAutoHideSetterTests.testKeepOverlayStyleRevertsLegacyStyleBackToOverlay`.
  Generalizing: whenever a value is both set by the app AND recalculated
  autonomously by the framework in response to a system event (not just
  the scroller — other candidates: `NSWindow.appearance`, `NSApplication`
  under a theme change, `NSTextView` under automatic spell-check), a "set
  once" gate is insufficient by definition — it needs to either keep
  reinforcing continuously or observe the relevant system event and react
  to it.

### Methodology: a finding here has two mandatory phases

1. **Static suspicion** — find one of the risk patterns above, record it
   as a candidate.
2. **Runtime confirmation** — EVERY candidate that describes a visual
   effect (appears/disappears, animates wrong, doesn't recalculate size)
   needs a real confirmation, not just a code read:
   - Add a step to the walkthrough in
     `UITestRunner/Sources/uitestrunner/Walkthrough/` that reproduces the
     scenario (e.g., expand the tree until it overflows, then check via AX
     that the scrollbar appears).
   - Run it with `scripts/run_ui_test.sh` (or `--plan`); `validate.sh`
     runs both passes. It doesn't use `xcodebuild` or `swift test`.
   - Confirm the test FAILS on the current code (proving the bug is real
     and that the test actually catches it) before applying the fix, then
     confirm it PASSES after the fix.
   - If it's not possible to write a reasonable automated test for a
     specific candidate (e.g., behavior that depends on a user system
     preference), say so explicitly in the finding and mark it "requires
     manual verification" instead of pretending it was confirmed.
   A finding with neither of the two confirmations above is a SUSPICION,
   not a finding — report it as such (its own section, not alongside
   confirmed ones).

## Logic tests (what still belongs in a unit test here)

Pure rendering bugs are not reachable by unit test (XCTest doesn't observe
pixels/`NSScroller`). But the LOGIC that feeds the render is sometimes
testable in isolation — and SHOULD get a unit test when it is:

- Reference vs. value semantics of a cache/state shared between Views
  (e.g.,
  `BoundedFolderNodeCacheTests.testReferenceSemanticsShareMutationsAcrossHolders`)
  — proves the PROPERTY the fan-out bug depended on, without needing to
  render anything.
- Pure functions that compute what goes on screen (formatting, sorting,
  filtering, manually computed geometry) — not the rendering itself.
- Guard conditions that decide WHETHER something should re-render (e.g.,
  "only apply if `expandedPaths.contains(url)`") — test the condition in
  isolation from the View.

Don't force a unit test for something only observable by actually running
the app — that produces a test that always passes and proves nothing (a
false sense of security), which is worse than admitting "this needs a UI
test".

## Classification, ROI, Safety Gate, finding format

Reuse `eval.md`'s scheme in full: IDs `[Severity][Impact]-[ROIx100]`, the
ROI formula, Safety Gate, the NOT WORTH section, the "Findings skipped by
comments" section. Don't duplicate it here — the only difference is the
SCOPE (rendering, not architecture) and the extra runtime-confirmation
REQUIREMENT described above.

## Final result

Generate/update `TODO/RENDER_CODE_REVIEW.md`, incrementally, following the
same discipline as `TODO/ARCHITECTURE_CODE_REVIEW.md` (delete findings from
the file as soon as they're fixed and tested — don't mark them as done).
Each confirmed finding must link to the UI test that proves it (file path +
test method name).
