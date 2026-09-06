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

## F2 — decorative icons exposed a system-localized accessibility label  ✅ FIXED

- **Symptom:** with the app forced English the AX tree still showed `AXImage #folder desc="Mover"`
  / `AXImage #photo desc="Foto"`. These `Image(systemName:)` icons had no explicit label, so
  VoiceOver read SF Symbols' built-in label, which follows the *system* language, not the app's.
- **Where:** `FooterBarView.iconSizeControl` (`photo` ×2), `EmptyDirectoryView` (`folder`,
  `doc.text.magnifyingglass`, `lock.fill`), `PathBarView` (`folder`).
- **Fix:** `.accessibilityHidden(true)` on all of them — they're purely decorative next to real
  text labels. No visible/interaction change.

---

## Runner note — if a run wedges

If the app or the automation subsystem gets stuck, the script's pre-run `pkill` clears leftovers;
otherwise wait ~5 min (15 at most) and re-run — it frees on its own.
