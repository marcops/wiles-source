# UI Test Plan — AXUIElement walkthrough

The suite lives in `UITestRunner/` — a standalone SwiftPM executable that drives a debug
`Wiles.app` from the outside via the macOS Accessibility API. No XCUITest, no `xcodebuild`.

- `scripts/run_ui_test.sh` — builds app + runner, kills stragglers, wipes the isolated
  `com.marco.wiles.uitest` defaults domain, runs. No lint step.
  - default: the FEATURES.md feature tour (`Walkthrough.swift`) — one launch, all 20 docs
    features + the language round-trip.
  - `--plan` : the deeper suite (`PlanWalkthrough.swift`), Phases A–D below.
  - `--screenshots` : stage every feature, capture `<slug>-{light,dark}.png` into
    `wiles-public/docs/screenshots/features/`.
  - `--fast` (scale 0.3) / `--slow` (1.0) / `--scale <n>` : the one speed knob is
    `Timing.scale`, default 0.5 (2× the base timings).
- `scripts/validate.sh` runs both passes and fails the gate on any failing check.
- First run needs Accessibility permission for the controlling terminal
  (System Settings ▸ Privacy & Security ▸ Accessibility). A wedged/throttled run → idle
  10–15 min (RunningBoard backs off after ~25 launch/kill cycles).

Model: one launch per pass, continue-on-failure — every `feat…()` step records its own
`reporter.check(...)` results and returns even on failure, so one run surfaces every break.

## Coverage matrix (target ≥ 80%)

| Area | Cases in scope | Covered | Notes on the gap |
| --- | --- | --- | --- |
| Shell & windows | ~8 | 5 | 2-window independence, frame-persist-across-relaunch left out (relaunch is flaky) |
| Navigation | ~12 | 10 | breadcrumb-segment click, Recents refresh |
| Selection | ~10 | 9 | rubber-band drag-select (synthetic drag unreliable) |
| File operations | ~18 | 16 | paste-into-same-folder "copy" suffix, multi-file drag |
| Sort & view | ~14 | 13 | column resize |
| Search | ~8 | 7 | invalid-filter explanation |
| Sidebar | ~10 | 9 | favourite reorder (drag) |
| Modals | ~18 | 17 | folder-picker sheet |
| Footer / inspector | ~5 | 4 | — |
| **Total** | **~103** | **~90 (~87%)** | remaining ~13% is drag-and-drop / multi-window / OS-integration that AX input can't drive |

## Suites

### FEATURES tour — `Walkthrough.swift` (21 steps / ~57 checks)

Language round-trip (+ F1 live re-localize), launch shell, Grid/List, Directory Tree,
Favorites/Places, Search, File Properties, Symbolic Links, Compress to ZIP, Undo/Redo
(Move to Trash), Batch Rename, Image Converter, Archive Inspector, Duplicate Finder,
Integrated Terminal, Disk Usage, Connect to Server, Auto-Organization, HTTP Sharing, Tags,
Smart Folders, Appearance Settings.

### `--plan` — `PlanWalkthrough.swift`

**Phase A — core shell / nav / content (`+Features.swift`, 27 steps)**
new+close window, sidebar headers, section-collapse persists, hide/show section, directory
tree drill-in, smart-folders section, path-bar nav, back/forward/enclosing, new folder +
rename, new file + rename, rename undo/redo, cut+paste, copy+paste, keyboard selection,
select-all + clear, sort order asc≠desc, icon zoom, Quick Look, empty directory, footer
terminal button, toggle preview, settings tabs, help sheet, shortcuts HUD, about sheet,
feedback sheet.

**Phase B — deeper behaviour (`+PhaseB.swift`, 12 steps)**
chmod in Properties, archive extract, file shredder, tag assign, copy path, PDF merge,
duplicate-finder scan (real pair), compress-with-password sheet, smart-folder round trip,
HTTP server start/fetch/stop, GNOME Enter-to-open mode, preference-persistence sweep.

**Phase C — corner cases (`+Corners.swift`, 19 steps)**
shift-click range, ⌘-click deselect one, click-empty deselect, arrow past last row,
rename-onto-existing (no clobber), rename with "/", New Folder auto-increment, every Sort
By key reorders, icon-zoom clamp, ⇧⌘. hidden-files toggle, no-match search + clear, ⌘I
properties, ⌘⌫ + undo, bad path refused, ⌘[/]/↑ history nav, Places entry navigates,
List column-header sort, compact-mode toggle, auto-hide sidebar.
(type-ahead jump dropped — Wiles has no type-ahead row jump.)

**Phase D — search / sidebar / modal / footer corners (`+Corners2.swift`, 10 steps)**
search scope toggle, `kind:` filter token, short content-term warning, Images quick filter,
add/remove Favorite, tag-filter navigates, symlink modal reopen, move-collision sheet,
status-bar count reflects selection, preview pane follows selection.
(smart-folder context menu dropped — a SwiftUI sidebar `.contextMenu` can't be raised by
synthetic input; the round-trip is covered by `featSmartFolderRoundTrip` in Phase B.)

## Not automated (the ~13%)

Drag-and-drop (row→folder, →path bar, →Favorites reorder, external file in), two-window
independence, window-frame persistence across relaunch, "Open With" launching a real app,
AirDrop/Share-sheet, column resize, live external-change refresh races.

## Rules

- Production source (`Sources/Wiles/`) is off-limits except adding a missing accessibility
  identifier, and only after asking.
- A finding that's a real Wiles bug → note it in `UI_TEST_FINDINGS.md`, don't paper over it
  in the test.
- Comments in the runner: one short line each, never blocks.
