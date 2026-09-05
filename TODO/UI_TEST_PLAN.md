# WilesLaunchUITests — Full-Feature UI Test Plan

Goal: grow `Tests/WilesUITests/WilesLaunchUITests.swift` from the current launch+minimise
smoke test into a suite that exercises **every feature the app ships**, one feature at a
time, without ever touching production source (except adding an accessibility id after
explicit approval — see §4).

## 0. Working loop (per feature)

**One single test method.** `WilesLaunchUITests` keeps exactly ONE `func test…()` that
does ONE app launch and walks every feature in sequence. Never add a second test method —
each method re-runs `setUp` (relaunch) + `tearDown` (terminate), which is both flaky and
hammers the app with launches. Never edit `setUp`/`tearDown`.

1. Pick the next unchecked feature from §2, in order.
2. Append **one** small `// MARK:`-delimited assertion block for it to the end of the
   existing test method in `WilesLaunchUITests.swift` only. Keep it tiny — a couple of
   assertions, not a scenario.
3. Run just that file:
   ```
   xcodebuild test -scheme Wiles \
     -only-testing:WilesUITests/WilesLaunchUITests \
     -skip-testing:WilesTests \
     -destination 'platform=macOS,arch=arm64'
   ```
4. **Pass** → self-audit the diff against §3, then `git commit` (Conventional Commits,
   English: `test(ui): …`).
5. **Fail** → `git checkout` the test file back to the last green commit. Re-add the block
   **one line at a time**, re-running after each added line, until the exact failing line
   is identified. Fix that line (test-side only) or, if it needs a missing accessibility
   id, stop and ask (see §4). Never "reinvent" the feature or press on past a red bar.
6. Check the box here, note the commit sha, move to the next feature.

Space the `xcodebuild` runs out — one at a time, not back-to-back.

Rules: no `if element.exists { … }` without an assertion; never `XCTAssertNotNil` an
`XCUIElement`; every check is `element.exists` / `element.waitForExistence(timeout:)`.
One feature = one commit. Never batch.

## 1. Test host facts

- Launches via `XCUIApplication`, `launchArguments = ["--ui-testing"]` (suppresses the
  first-run permission prompts — `WilesApp.swift:87`).
- Only runnable through Xcode / `xcodebuild test` against the `Wiles` scheme, never
  `swift test` (SPM makes a unit bundle, not a ui-testing bundle).
- Existing green UI test files (do not regress): `WilesLaunchUITests`,
  `GlobalKeyMonitorUITests`, `NewFolderRenameUITests`, `SidebarScrollingUITests`.

### Accessibility identifiers that already exist (safe to use, no source change)

| id | source |
| --- | --- |
| `Section_FAVORITES` / `Section_NETWORK` / `Section_PLACES` / `Section_DIRECTORY_TREE` / `Section_TAGS` / `Section_SMART_FOLDERS` | `SidebarSectionHeaderView.swift:39` |
| `Tag_<name>` | `TagsSectionView.swift:41` |
| sidebar row = `item.name` | `SidebarRowView.swift:54` |
| directory-tree row = `node.name` | `DirectoryTreeNodeView.swift:129` |
| `Status Bar` | `FooterBarView.swift:50` |
| `OperationsProgressButton` | `OperationsButtonView.swift:22` |
| `InlineRenameField` | `InlineRenameField.swift` |
| `PathBarTextField` | `PathBarView.swift:78` |
| `SearchTextField` | `HeaderBarView.swift:202` |
| `View Mode` + per-mode id via `accessibilityID(for:)` | `HeaderBarView.swift:409/426` |
| file row/card = `item.name` (label, not id) | `FileListView.swift:143`, `FileGridCardItemView.swift:66` |

Everything else is reached through localized `accessibilityLabel` text (menus, footer
buttons, modal fields) — usable but brittle across languages; the run is English by
default so acceptable.

## 2. Feature checklist

Legend: `[ ]` todo · `[x] <sha>` done · **A** = doable with existing ids/labels · **B** =
needs a new accessibility id (ask first, §4).

### Phase A — existing shell & already covered

- [x] `d9a4364` App launches, main window appears, FAVORITES section present + hittable, Status Bar present, FAVORITES collapse/expand survives (current `testAppLaunchesAndCoreShellIsVisible`)
- [ ] **A** New window (⌘N) opens a second window; ⌘W closes it (extend/mirror `GlobalKeyMonitorUITests`)
- [ ] **A** Directory-tree node expand/collapse (mirror `SidebarScrollingUITests` minus the scrollbar assert)

### Phase A — sidebar

- [ ] **A** Every sidebar section header (`Section_*`) exists and is hittable
- [ ] **A** Section collapse state persists across relaunch (collapse, `terminate`, `launch`, still collapsed)
- [ ] **A** Hide a section via its context menu; it disappears; re-show from View ▸ Sidebar menu
- [ ] **A** Click a PLACES row (e.g. the user home / Applications) → content pane repopulates
- [ ] **A** DIRECTORY TREE: expand root, click a child node → navigates
- [ ] **A** TAGS section: a `Tag_*` row exists (create a tagged file in a temp dir first) and click filters content
- [ ] **A** SMART FOLDERS section renders (empty state acceptable if none saved)
- [ ] **B** Favorite toggle button adds/removes a folder from FAVORITES (needs id on `FavoriteToggleButton`)
- [ ] **B** Sidebar mode switch (full ↔ icon-only) from Sidebar settings (needs id)

### Phase A — header bar & navigation

- [ ] **A** Path bar: click, type a path, ⏎ → navigates there (`PathBarTextField`)
- [ ] **A** Search: focus `SearchTextField`, type → file list filters; clear → restores
- [ ] **A** View mode: toggle Grid ↔ List via `View Mode` control; grid/list rows appear accordingly
- [ ] **A** Go ▸ Back / Forward / Enclosing Folder (⌘[ / ⌘] / ⌘↑) after navigating
- [ ] **B** Sort menu: change sort order (Name → Date/Size/Kind…) and verify row order (needs id on sort control)
- [ ] **B** Header center mode cycle (needs id)

### Phase A — content operations

- [ ] **A** New Folder (⇧⌘N) → row appears, enters inline rename, commits typed name (already: `NewFolderRenameUITests` — port a variant)
- [ ] **A** New File (⌘N in content? confirm shortcut) → row appears + inline rename
- [ ] **A** Select a file row, ⌘I → File Properties sheet opens; close via footer button
- [ ] **A** Select a file, space → Quick Look panel; space again closes
- [ ] **A** Select all (⌘A) selects every row
- [ ] **A** Move to Trash (⌘⌫) on a temp file → row disappears; ⌘Z restores it
- [ ] **A** Cut (⌘X) / Paste (⌘V) a temp file into a subfolder → moved
- [ ] **A** Copy (⌘C) / Paste (⌘V) → duplicate created
- [ ] **A** Undo (⌘Z) / Redo (⇧⌘Z) round-trip on a rename
- [ ] **B** Keyboard selection navigation (arrow keys move highlight) — needs a way to read selected row
- [ ] **B** List-view column resize handle drag (needs id on `ColumnResizeHandle`)
- [ ] **B** List-view column show/hide from header context menu (needs id)
- [ ] **B** Icon-size zoom (⌘+ / ⌘-) changes grid cell size (needs measurable id)
- [ ] **A** Empty-directory view shows in a freshly made empty temp folder

### Phase A — footer & trailing inspector

- [ ] **A** Footer terminal toggle button shows/hides the integrated terminal (label `actToggleTerminal`)
- [ ] **A** Toggle Terminal shortcut does the same
- [ ] **A** `OperationsProgressButton` — trigger a slow copy, button + popover appear
- [ ] **A** Toggle Preview (shortcut) → preview pane appears for a selected file
- [ ] **A** Toggle Disk Usage (shortcut) → disk-usage visualizer pane appears
- [ ] **A** Preview pane "More Info" button (`moreInfo` label) expands metadata

### Phase A — modals (open + close each, assert scaffold present)

- [ ] **A** Settings (⌘,) — opens; switch each tab: General / Appearance / Sidebar / Advanced
- [ ] **A** Appearance settings: change theme (Light/Dark/System) — window appearance follows
- [ ] **A** Appearance settings: change app language — a visible label switches language
- [ ] **A** Connect to Server (⌘K) — sheet opens, cancel closes
- [ ] **A** Help (⌘?) — sheet opens, close
- [ ] **A** Shortcuts HUD (shortcut) — overlay opens, Escape closes
- [ ] **A** About — sheet opens, close
- [ ] **A** Feedback — sheet opens, close
- [ ] **A** Tools ▸ Auto-Organization — sheet opens, close
- [ ] **A** Tools ▸ Duplicate Cleaner — sheet opens (scan empty temp dir), close
- [ ] **B** File Properties — covered above; also chmod control (needs id)
- [ ] **B** Image Converter (context menu on an image) — needs a real image + menu label
- [ ] **B** Symlink sheet (context menu) — needs menu label id
- [ ] **B** HTTP Share sheet (context menu on a folder) — needs menu label id
- [ ] **B** Archive Inspector (double-click / context menu on a .zip) — needs id
- [ ] **B** Password Compress (context menu on selection) — needs id
- [ ] **B** Batch Rename (context menu on multi-selection) — needs id
- [ ] **B** Save Smart Folder (from an active search) — needs id

### Phase B — deeper feature behaviour (all need new ids, ask first)

- [ ] **B** Archive: compress selection → .zip created; extract .zip → folder created
- [ ] **B** File Shredder (context menu) → confirm dialog, file gone, not in Trash
- [ ] **B** Auto-Organization: add a rule, drop a matching file, it moves
- [ ] **B** Symlink creation produces a working link
- [ ] **B** PDF merge on multi-PDF selection
- [ ] **B** Network discovery populates NETWORK section (environment-dependent — may skip)
- [ ] **B** HTTP local server: start share, hit the port, stop
- [ ] **B** Finder tag assign/remove via context menu; tag colour name localized
- [ ] **B** Copy Path variants (POSIX / name / etc.) land the right string on the pasteboard
- [ ] **B** Smart folder: save a query, run it, results match
- [ ] **B** Navigation mode (GNOME vs macOS): Enter/F2 semantics differ
- [ ] **B** Full UI-pref persistence sweep: status-bar vis, icon size, view mode, sidebar
      mode, shortcut mode, section collapse, expanded folders, language — all restore on relaunch

## 3. Rules self-audit checklist (run before every commit)

Scoped to the test-file diff only. Tick each before committing the feature.

### From `GENERAL_RULES.md`

- [ ] No proactive extras — only the one feature asked for, nothing "while in there"
- [ ] No workarounds — a red bar is root-caused (bisected line-by-line), not skipped/masked
- [ ] No unilateral tech decisions — platform/OS/arch scope untouched; ask if a choice appears
- [ ] No unsolicited memory writes
- [ ] Repeated command sequences → a script (the xcodebuild-test invocation, if run >2×)
- [ ] Comments ≤ 1–2 lines, WHY-only, default zero
- [ ] Only read files in scope for enumerating features; ask before wandering wider
- [ ] No `osascript` anywhere
- [ ] When unsure → ask, don't guess

### From `DEV_RULES.md`

- [ ] Inspected the real source for every id/label/selector used — no guessed identifiers
- [ ] KISS/YAGNI — no test helper framework built ahead of need
- [ ] DRY — shared setup (temp dir, launch, teardown) extracted, not copy-pasted per test
- [ ] No inline compound conditions (3+ terms) — extract a named helper
- [ ] No magic numbers — timeouts/counts are named constants when reused
- [ ] No unnecessary comments
- [ ] Minimal diff — only `WilesLaunchUITests.swift` touched
- [ ] **Production source never bends for the test** — if a test needs source to differ, the
      test is wrong; the only allowed source change is an accessibility id, after approval
- [ ] Never destroy user data — every test writes only inside a fresh
      `NSTemporaryDirectory()` subfolder, cleaned in `tearDown`; never touches real user files

### From `SWIFT_LANG_RULES.md`

- [ ] One type per file (the `XCTestCase` subclass stays the only top-level type)
- [ ] `@MainActor` on the test case (matches existing)
- [ ] No `AnyView`, no `print(` (use `XCTAssert*` / no logging)
- [ ] Event monitors / observers, if any added, torn down in `tearDown`
- [ ] No hardcoded locale list — if asserting localized text, drive it off the resource set
- [ ] `continueAfterFailure = false` kept

### From `WILES_RULES.md`

- [ ] Commit message: English, Conventional Commits (`test(ui): …`)
- [ ] Response language: English
- [ ] Zero hardcoded absolute paths / raw `"/tmp"` — use
      `URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)`
- [ ] Strict test isolation — no mutation of real `UserDefaults` / saved smart folders /
      rule lists without restore in a guaranteed `defer` / `tearDown`
- [ ] New UI test methods live in a file already registered in `Package.swift` (this one is)
- [ ] Strict UI-test verification standards (asserted, not `if exists`)
- [ ] Section-collapse / pref-persistence tests restore original defaults afterwards
- [ ] Completed items in this file get **deleted** when the whole plan is done, not left as `[x]`
      (keep the shas until then for the bisect trail)

### From `WILES_UI_UX_RULES.md`

- [ ] Not applicable to test code directly; if a test reveals a modal not built on
      `ModalScaffoldView` or a HIG deviation, flag it to the user — don't fix source

### Lint (`swiftlint --strict` must stay green — `.swiftlint.yml` `custom_rules`)

- [ ] `one_type_per_file`, `no_print_in_production`, `no_any_view`,
      `no_inline_compound_condition`, `no_hardcoded_secrets`, `no_redundant_bool_comparison`
      all pass on the new code
- [ ] `swiftformat` leaves the file unchanged (run it, or match surrounding style exactly)

## 4. Accessibility ids to request before Phase B

Each of these is a **stop-and-ask** item — do not add to `Sources/` without explicit
sign-off. Batch the ask per feature, mirroring the existing pattern
(`.accessibilityIdentifier("…")` next to an existing `.accessibilityLabel`).

| # | element | file (approx) | proposed id |
| --- | --- | --- | --- |
| 1 | Favorite toggle button | `Views/Components/FavoriteToggleButton.swift` | `FavoriteToggle` |
| 2 | Sidebar mode switch | `Views/Settings/SidebarSettingsView.swift` | `SidebarModePicker` |
| 3 | Sort control | `Views/Header/HeaderBarView.swift` | `Sort Order` |
| 4 | Header center-mode control | `Views/Header/HeaderBarView.swift` | `Header Center Mode` |
| 5 | Selected file row trait/value | `Views/Content/FileListView.swift` / `FileGridCardItemView.swift` | expose `.isSelected` trait |
| 6 | List column resize handle | `Views/Content/ColumnResizeHandle.swift` | `ColumnResizeHandle_<col>` |
| 7 | List header (column show/hide menu) | `Views/Content/FileListHeaderView.swift` | `FileListHeader` |
| 8 | Grid cell (measurable for zoom) | `Views/Content/FileGridCardItemView.swift` | `FileCard_<name>` |
| 9 | Context-menu items (Image Converter, Symlink, HTTP Share, Inspect Archive, Compress, Batch Rename, Shred, Save Smart Folder, Copy Path…) | `Views/Components/SharedFileItemContextMenu.swift` | ids per action |
| 10 | Modal scaffold root (generic close/assert anchor) | `Views/Components/Modal/ModalScaffoldView.swift` | `Modal_<title>` |
| 11 | Settings tab buttons | `Views/Settings/SettingsView.swift` | `SettingsTab_<name>` |
| 12 | Terminal container | `Views/Content/IntegratedTerminalView.swift` | `IntegratedTerminal` |
| 13 | Preview pane / Disk-usage pane containers | `Views/Sidebar/PreviewSidebarView.swift`, `Features/DiskSpaceVisualizer/DiskUsageSidebarView.swift` | `PreviewPane` / `DiskUsagePane` |

## 5. Progress log

| date | feature | commit | result |
| --- | --- | --- | --- |
| 2026-09-05 | plan created | — | — |
