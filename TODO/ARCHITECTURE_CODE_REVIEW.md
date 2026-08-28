# Architecture & Code Review — Remaining Work

Everything from the review pass has been implemented and removed from this file (commit history is the record).
State: `swift build -c debug` clean (zero warnings), `swiftlint --strict` clean, `swiftformat --lint` clean, **115 unit tests pass** (incl. the C1 red→green regression suite).

The only thing still needing a call from you, plus the deliberate "won't do / monitor / later" list, are below.

---

## Needs a decision from you

### A5 — `ModalStore` is documented as shared but is actually per-window (doc drift)
- **Arquivo:** `WindowUIState.swift` doc comment, `MainContentView.init`.
- `MainContentView.init` constructs `ModalStore()` per window, but the docs (and `SWIFT_LANG_RULES.md`) say ownerless/background error alerts live on a *shared* `ModalStore`. So a background-service error (`AutoOrganizationService` scan failure) reaches no visible alert — `ErrorReporter.report` only.
- **Escolha uma:** (a) restore a genuinely shared `ModalStore` for the ownerless-error case; (b) update the docs to say every error alert is per-window and accept that background-service errors are log-only.

---

## Won't Do (user decision, this pass)

- **M13** — Batch rename fails on transient collisions (renumbering, swaps). Renames applied one-by-one. Two-phase rename remains a valid future improvement.
- **M14** — Changing sort order re-reads the directory from disk instead of an in-memory re-sort. User keeps the disk reload (guarantees a fully fresh listing every sort).
- **A3** — No compound/transaction undo. A 50-file batch rename / paste takes 50 ⌘Z. `case batch([UndoActionType])` remains a valid, contained future improvement.
- **L3** — `NavigationStore.currentURL.didSet` writes `UserDefaults` synchronously per navigation (~3 round-trips with `recentOpenedURLs` + `addToRecents`). Acceptable today; if ever touched, coalesce like `scheduleExpandedTreePathsSave`.

---

## Monitor Only (no change recommended now)

- **A1** — Store→AppState callback wiring via stored closures (`onSearchQueryChanged`, `onVolumeUnreachable`, `onRenameCleared`, `refreshHandler`). Deliberate idiom, avoids a retain cycle. If it grows past ~6 hooks, consider an explicit `AppStateEvent` enum + one `handle(_:)` on `AppState`.
- **A4** — `WindowUIState`'s ~20 discrete sheet/alert flags + the `isAnyModalPresented` OR. Currently correct. A single `enum PresentedModal` with `var presentedModal: PresentedModal?` would make "one modal at a time" structural — do it the next time 2–3 new modals are added, or if a "two sheets at once" bug appears.
- **PR2** — Favorites / recents / last-opened persist as raw path strings, not security-scoped bookmarks. Fine while unsandboxed; a wide-reaching migration (`NavigationStore`, `PreferencesStore`, smart-folder scopes, auto-organization rule URLs, recent servers) if the app ever adopts the sandbox.
- **PR3** — Auto-organization has no dry-run/preview and no activity log — only a per-rule counter. A "what would this rule do" preview + a lightweight move log (last N moves, per-entry undo) would materially reduce the "where did my file go" risk. H2's honest "no undo" notice now ships; this is the next step for trust.
- **P1 (remainder)** — `FolderNode.loadSubfolders` / `buildRootTree` recursive **synchronous** directory walk. The per-item `NSWorkspace.icon` loops are fixed; this walk still needs the sidebar-view review before touching.
