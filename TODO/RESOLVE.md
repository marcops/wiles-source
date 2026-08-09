# Wiles — Resolution Plan

Action checklist from the 2026-08-09 AGENTS.md-compliance audit. Ordered by priority. Each fix must
follow rule 28 (red-green test) and rule 38 (self-audit before commit) from `.agents/AGENTS.md`.

---

## P3 — Architecture cleanup

- [ ] **Sidebar context menu duplication** — `SidebarRowView.swift:98-133` and
      `DirectoryTreeNodeView.swift:75-96` hand-roll the same Open/Copy Path/Properties menu.
      Extract a shared `SidebarItemContextMenu` view, use it in both places. Minimal-diff: don't
      touch unrelated sidebar layout while doing this (per your standing "minimal UI changes"
      preference).
- [ ] **`ColumnAutoFitService.swift`** taking `AppState` directly — pass only the primitives it
      actually needs instead. Small, contained change (1 of ~45 Service files).
- [ ] **`pt.lproj` has 3 keys no other language has**: `actRefreshShortcut`, `actToggleStatusBar`,
      `tabShortcuts` (`Sources/Wiles/Resources/pt.lproj/Localizable.strings:15,18,317`). Determine
      which: either these back a real shipped feature and need translating into the other 14
      languages, or they're dead/orphaned and should be deleted from `pt`. Don't guess — grep the
      Swift source for where these keys are actually read (if anywhere) first.

## P4 — Rule 3 / Rule 7 length violations (lower urgency, real debt)

Decompose into `@ViewBuilder` sub-properties / private helpers. Suggested order by size:
- [ ] `Views/Components/SharedFileItemContextMenu.swift` (240-line body; also move the unrelated
      `colorForTag(_:)` free function and `AppState` extension out of this file — rule 14/SRP)
- [ ] `Views/Content/MainContentView.swift` (142-line body, ~18 chained `.sheet`)
- [ ] `Views/Modals/FilePropertiesSheet.swift` (132-line body)
- [ ] `Views/Sidebar/SidebarView.swift` (125-line body)
- [ ] `Views/Sidebar/SidebarRowView.swift` (117-line body — do this alongside the context-menu
      extraction above, it'll shrink naturally)
- [ ] `Views/Content/FileGridView.swift` / `FileListView.swift` (~100-line bodies)
- [ ] `Features/DuplicateCleaner/DuplicateDetectionService.swift:findDuplicates(in:)` (47 lines)
- [ ] `Views/Components/FileItemInteractionsModifier.swift:body(content:)` (39 lines — this is
      shared infra, prioritize despite being "only" medium severity)
- [ ] `Views/Modals/AutoOrganizationSheet.swift:ruleRow(_:)` (43 lines, low)
- [ ] `Views/Content/FileColumnView.swift:selectItem(...)` (36 lines, low)

## P5 — Small mechanical fixes (animation, test isolation, locale formatting)

- [ ] **`Views/Content/FileColumnView.swift:39`** — the "Whole Mac" search-results `.animation` is
      missing the `paginate ? nil : ...` guard that `FileListView`/`FileGridView`/the sibling
      column browser already use. One-line fix, copy the existing pattern.
- [ ] **`Tests/WilesTests/Services/PermissionTests.swift:38-84`** — mutates real
      `UserDefaults.standard` keys with a manual end-of-function restore instead of `defer`.
      Convert to the `defer`-based pattern `AppStateCoreTests.swift:278-307` already uses correctly,
      so an assertion failure mid-test can't leave real user persistence corrupted.
- [ ] **`Tests/WilesTests/Features/HttpSharing/LocalHttpServerServiceTests.swift`** — spot-check
      whether the 5 tests sharing `.shared` are ever order-dependent/flaky; add an explicit
      initial-state reset before each if so. (Low confidence finding — verify before spending time.)
- [ ] Cosmetic: fix the merged-line formatting (`"key1" = "val1";"key2" = "val2";` on one line) in
      10 locale files (`ar`, `it`, `ja`, `ko`, `nl`, `pl`, `ru`, `sv`, `tr`, `zh-Hans`) to match the
      one-pair-per-line formatting the other 5 already use. Harmless functionally, lowest priority.

## P7 — Product decisions (need your call, not just a fix)

- [ ] **Wi-Fi folder sharing has no authentication.** `NetworkServerService.swift`,
      `LocalHttpServerService.swift`, `HttpShareSheet.swift` — zero password/credential/auth
      anywhere. Decide: add a passcode/PIN to the share sheet, or explicitly document it as
      "trusted network only" in the UI (a one-line warning in `HttpShareSheet`) so it's a known
      tradeoff, not a silent gap.
- [ ] **No CI.** Neither `wiles` nor `wiles-public` has `.github/workflows/`. `scripts/validate.sh`
      is comprehensive but 100% manual. Minimal fix: a GitHub Actions workflow that runs
      `validate.sh` on push to `main` — turns rule 38 (mandatory self-audit) into an actual gate
      instead of an honor system.
- [ ] **No crash/error observability.** Zero `os_log`/`Logger` usage anywhere, no crash reporting.
      Given the app is unsandboxed/unnotarized, a crash in the wild is invisible unless a user
      files a GitHub issue. Consider a minimal local crash log (signal/NSException handler writing
      to a file in Application Support) as a first step — no need for a third-party SDK given the
      100%-native-APIs rule.
