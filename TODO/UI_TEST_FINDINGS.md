# UI-test findings — app bugs surfaced by the AXUIElement walkthrough

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
  a missing translation.
- **Fix:** add `.onChange(of: appState.preferences.appearance.appLanguage) { … reload free-space }`
  (mirrors `PathBarView` / `SidebarView`, which already do this for their derived strings).
- **ROI:** high — one-line-ish, matches an existing pattern, user-visible. Worth fixing.

---
