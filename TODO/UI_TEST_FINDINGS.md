# UI-test findings — app bugs / oddities surfaced by the AXUIElement walkthrough

Recorded while building `UITestRunner/`'s FEATURES.md + UI_TEST_PLAN.md coverage.

---

## F1 — Footer free-space string didn't re-localize on a live language change  ✅ FIXED

- **Where:** `Sources/Wiles/Views/Footer/FooterBarView.swift`.
- **Was:** `freeSpaceText` loaded once in `.task(id: currentURL)` and never recomputed when
  `appLanguage` changed, so the status bar kept the old locale's `freeSpaceFormat`
  (`339,6 GB livre` after switching to English — the `en` key exists, it was a refresh bug).
- **Fix:** added `.onChange(of: appLanguage) { Task { freeSpaceText = await loadFreeSpaceText() } }`
  — same pattern `SidebarView` / `PathBarView` already use for their derived strings.

---

## F2 — a couple of static accessibility labels stay in the old locale (open, cosmetic)

- **Symptom:** with the app forced English the AX tree still showed `AXImage #folder desc="Mover"`
  and `AXImage #photo desc="Foto"` (empty-state / footer icons). Same root cause as F1 — an
  `accessibilityLabel` captured before a language switch. VoiceOver-only, low ROI. Not chased to a
  specific view; likely fixed by the same `.onChange(of: appLanguage)` treatment where those
  images live.

---

## Runner note — if a run wedges

If the app or the automation subsystem gets stuck, the script's pre-run `pkill` clears leftovers;
otherwise wait ~5 min (15 at most) and re-run — it frees on its own.
