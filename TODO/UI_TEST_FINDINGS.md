# UI-test findings — app bugs / oddities surfaced by the AXUIElement walkthrough

Recorded while building `UITestRunner/`'s FEATURES.md + UI_TEST_PLAN.md coverage.
Each entry: what's wrong, how it showed up, rough fix, ROI.

---

## F1 — Footer free-space string doesn't re-localize on a live language change

- **Where:** `Sources/Wiles/Views/Footer/FooterBarView.swift` — `freeSpaceText` is loaded once
  in `.task { freeSpaceText = await appState.loadFreeSpaceText() }` and never recomputed when
  `appState.preferences.appearance.appLanguage` changes.
- **Symptom:** switch language at runtime (Settings ▸ General ▸ Language) and the status bar
  still reads e.g. `339,6 GB livre` (old locale's `freeSpaceFormat`) until the folder is
  re-listed. The `en` key exists (`"freeSpaceFormat" = "%@ free"`), so it's a refresh bug, not
  a missing translation. (Worked around in `--screenshots` mode by launching already-English.)
- **Fix:** add `.onChange(of: appState.preferences.appearance.appLanguage) { … reload free-space }`
  (mirrors `PathBarView` / `SidebarView`, which already do this for their derived strings).
- **ROI:** high — one-line-ish, matches an existing pattern, user-visible. Worth fixing.

---

## F2 — (unconfirmed) a couple of accessibility labels stay in the old locale

- **Symptom:** even with the app forced English, the AX tree showed `AXImage #folder desc="Mover"`
  and `AXImage #photo desc="Foto"` in the header/footer. Same class as F1 — an `accessibilityLabel`
  string captured before a language switch and not refreshed. Cosmetic (VoiceOver only), low ROU.
- **Status:** not chased down to a specific view. Re-verify after F1 is fixed — likely the same
  root cause.

---

## Environment note — RunningBoard launch throttling

Not an app bug. Building the suite involved many `xcodebuild`-free `open`/kill cycles of
`Wiles.app`; after ~20+ the machine's UI-automation subsystem degrades — synthetic keystrokes
stop reliably reaching a focused SwiftUI `TextField`, sheets take many seconds to appear, AX
tree walks slow to a crawl. `scripts/run_ui_test.sh` already kills stragglers before each run,
but the fix for a wedged session is a reboot (or a long idle). Re-run the suites on a fresh
boot for the definitive pass.
