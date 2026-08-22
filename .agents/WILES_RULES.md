# WILES_RULES.md — Wiles Project Rules

Architecture decisions, release process, and workflow specific to the Wiles app. UI/UX design and interaction conventions live in `WILES_UI_UX_RULES.md`. Generic software-engineering principles live in `DEV_RULES.md`; generic Swift/SwiftUI/AppKit practices live in `SWIFT_LANG_RULES.md`.

## Native-First, Minimal Dependencies

- Prefer native Apple frameworks (AppKit, SwiftUI, Foundation, `AppleArchive`, native binaries like `ditto`, `NSWorkspace`, `NSPasteboard`) over third-party wrappers wherever a native API can do the job.
- The app currently has two justified external SPM dependencies (see `Package.swift`): **SwiftTerm** (terminal emulation) and **GitBeacon** (this project's own crash/error-reporting library — see "Error Reporting" below). Don't add another third-party dependency without asking first — the bar is "native genuinely can't do this," not convenience.
- The app MUST remain fast and lightweight. Proactively warn the user if a requested feature, architectural approach, or disk I/O pattern could slow it down, freeze the UI, or degrade UX — and propose a high-performance native alternative.

## Lint-Enforced Rules

Some of `SWIFT_LANG_RULES.md`'s rules are mechanically enforced here via `.swiftlint.yml` `custom_rules`, rather than relying on review: `one_type_per_file` (one top-level type per file), `no_any_view` (bans `AnyView(`), `no_print_in_production` (bans `print(` under `Sources/`, points to `ErrorReporter.report(...)` instead — see "Error Reporting" below). When adding a new mechanically-checkable rule, prefer extending this list over writing prose that has to be remembered.

## Error Reporting

- Use `ErrorReporter.report(error, context:)` (from the `GitBeacon` package) for logging/error reporting in production code — not `print()` (mechanically enforced by the `no_print_in_production` lint rule) and not `os_log`/`Logger` for error paths specifically (local debug-only logging via `os.Logger` is fine, as seen in `AppState+ColumnsAndActions.swift`).

## Shared Interaction Components (DRY in Practice)

- Never duplicate context menus, selection handlers, drag & drop handlers (`.fileItemInteractions`), hover highlighting (`.hoverHighlight`), icon rendering (`FileItemIconView`), or empty state indicators (`EmptyDirectoryView`) across `FileGridView`, `FileListView`, and `SidebarView`. Always use the shared ViewModifiers/components.
- Keep Views focused on layout declaration, Services (`FileSystemService`, `LocalizationService`, `ZipArchiveService`, etc.) focused on system logic, and `AppState` focused on application state.

## Self-Contained Feature Folder Shape

- Every self-contained feature lives under `Features/<Name>/` and pairs a `<Name>Service.swift` (the logic — filesystem work, parsing, computation) with a `<Name>SheetView.swift` (the UI, built on `ModalScaffoldView` per `WILES_UI_UX_RULES.md`). A `<Name>ServiceProtocol.swift` is added only when there's a genuine need for dependency injection/testability (e.g. to mock filesystem access in tests) — not by default for every new feature.
- Existing features following this shape: `ArchiveInspector` (`ArchiveInspectionService` + `ArchiveInspectionServiceProtocol` + `ArchiveInspectionSheetView`), `BatchRename` (`BatchRenameService` + `BatchRenameSheetView`), `DuplicateCleaner` (`DuplicateDetectionService` + `DuplicateCleanerSheetView`), `HttpSharing` (`LocalHttpServerService` + `HttpShareSheet`), `ImageConverter` (`ImageConverterService` + `ImageConverterSheetView`), and `SmartFolders` (`SmartFolderService` + `SmartFolderServiceProtocol` + `SaveSmartFolderSheetView`).
- `FileShredder` is the one outlier, not a model to copy: it's a `FileShredderService` invoked directly as a context-menu action (from `AppState+Operations.swift`) with no dedicated sheet, since shredding needs no configuration UI of its own. A new feature should default to the Service + SheetView pair above unless it has the same no-UI-needed shape.

## Complete State Persistence

- Every UI preference or state change (status bar visibility, icon size, view mode, sidebar mode, shortcut mode, section collapse states for `FAVORITES`/`MAC`/`RECENTS`/`DEVICES`/`DIRECTORY TREE`, expanded folder paths, language preference) MUST be saved to `UserDefaults` and restored exactly on next launch.

## macOS Menu Integration

- Merge View menu commands directly into native macOS system menus using `CommandGroup(after: .sidebar)` in `WilesApp.swift` instead of `CommandMenu("View")`, to avoid duplicate menu items in the menu bar.

## Communication & Commit Discipline

- **Git commit messages**: always in English, Conventional Commits format (`feat: ...`, `fix: ...`, `refactor: ...`).
- **Agent responses**: always in English, regardless of what language the user writes in.
- See "Rebuild & Release Workflow" below for when to build/relaunch vs. when to commit/push — they are not the same step, and `push_and_relaunch.sh` should not run in a single call by default.

## Rebuild & Release Workflow

Every code change must build with zero warnings — fix warnings immediately, even ones unrelated to the current task if noticed during a build.

Two distinct end-of-change steps, do not conflate them:
- **Build + relaunch only** (`swift build -c debug`, kill any running `Wiles`, copy binary+bundle into `Wiles.app`, codesign, reopen) — use this while the user is still testing/tuning something (e.g. trying a threshold value). Do NOT commit or push at this stage.
- **Full `scripts/push_and_relaunch.sh "<msg>" [--skip-commit]`** (build + relaunch + `git add`/commit `--no-verify`/push to origin/main) — only run once the user has confirmed the change is good, or when they explicitly ask for the full workflow. Default to `--skip-commit` until told to commit.

When reviewing/explaining a list of past changes (e.g. commits), go **one at a time** and wait for the user's decision — never dump the whole list at once.

## Testable Fixes Are Deferred, Not Skipped

For fixes/features in Wiles, don't write/run the actual unit test file immediately, even for pieces that are unit-testable — the user wants to manually test and review the real behavior first, before it's locked in with tests, since writing tests too early adds churn if the implementation changes after review.

- Still extract the logic into a testable shape as part of the fix itself (per `DEV_RULES.md`'s testing-discipline rule) and confirm the build is clean (zero warnings).
- Add an entry to `UI_TEST_BACKLOG.md` at the repo root for every pending test — both genuinely untestable pieces and testable-but-deferred pieces, same format, so nothing is forgotten.
- Only write and run the actual test once the user has manually tested and confirmed the change is correct ("deu ok"). Standing rule for all Wiles work, not a one-off.

## Available Scripts

- `scripts/push_and_relaunch.sh "<msg>" [--skip-commit]` — build+sign+relaunch, then commit+push. Default to `--skip-commit` until told to commit.
- `scripts/validate.sh` — build+test+lint+format, exit 0 = clean.
- `scripts/build_debug_app.sh` — builds a real `Wiles.app` bundle in debug mode so `WilesUITests` has something `XCUIApplication` can launch (`swift build` alone only produces a bare executable). Invoked as a Run Script build phase by the Xcode UI-test target; not usually run by hand.
- `scripts/test_timing.sh` — slowest 10 tests.
- `scripts/setup_test_ramdisk.sh` — mounts RAM disk for tests.
- Release (build → package → publish to GitHub Releases → update Homebrew Cask → push) is fully automated in `.github/workflows/release.yml` — no local script; push a `v*` tag or trigger it manually from the Actions tab.
- (General rule for turning any *other* repeated command sequence into a script lives in `GENERAL_RULES.md`.)

## Repository Architecture & Public/Private Separation

- **`marcops/wiles` (PUBLIC)**: public Homebrew cask formulas (`Casks/wiles.rb`), public release assets, documentation, public issue tracking. All Homebrew cask URLs MUST point exclusively to this repo (`https://raw.githubusercontent.com/marcops/wiles/main/...`).
- **`marcops/wiles-source` (PRIVATE)**: internal Swift source. NEVER reference private URLs (`wiles-source`) in public Homebrew formulas or public documentation.

## Automated Homebrew & Release Packaging Protocol

- **Zip packaging**: always `/usr/bin/zip -r -y dist/wiles-vX.Y.Z.zip Wiles.app` so the root `Wiles.app/` folder is preserved. Never use `ditto` directly on `Wiles.app` for Homebrew releases — it strips the root folder.
- **CDN cache busting (critical)**: `Casks/wiles.rb`'s `url` MUST use the exact git commit SHA where the `.zip` was pushed, never `main` — GitHub's Fastly CDN caches the old binary otherwise and causes a SHA256 mismatch.
- **Synchronous build & version verification**: always wait for `swift build -c release` to finish 100% synchronously before copy/codesign/zip. Always update `CFBundleShortVersionString`/`CFBundleVersion` in `Info.plist` to the target version. Always `strings Wiles.app/Contents/MacOS/Wiles | grep "X.Y.Z"` to verify the binary version before packaging.
- **SHA256 verification checklist**:
  1. Build release binary, wait for completion.
  2. Update `Info.plist` version strings.
  3. Copy binary + `Wiles_Wiles.bundle` into `Wiles.app`.
  4. Verify compiled binary version via `strings`.
  5. Validate the bundle exists: `find Wiles.app -name "*.bundle"`.
  6. Sign `Wiles.app` (`codesign -f -s -`).
  7. Package DMG (`hdiutil create ...`).
  8. Package ZIP (`/usr/bin/zip -r -y ...`).
  9. Compute `shasum -a 256`.
  10. Copy ZIP & DMG to the public tap repo.
  11. Push binaries to the public repo first, get the exact commit SHA.
  12. Update `Casks/wiles.rb` version/SHA256/URL with that SHA.
  13. Push the Cask update, verify live with `curl` before declaring completion.

## Release Checklist (Cutting a New Version)

1. In `wiles-source`: bump `appVersion` in `Sources/Wiles/Constants/AppConstants.swift`.
2. Run `scripts/validate.sh` (build/tests/lint/format) — must exit 0 before committing.
3. In `wiles-public`: add a `## Version X.Y.Z` entry to `RELEASE_NOTES.md` (top of file) — required by the release workflow's guard rail. Enforce the 5-full-version cap (see "Public RELEASE_NOTES.md" below): if this entry pushes the full-detail count past 5, fold the oldest full entry into `## Earlier Highlights` in the same edit.
4. Commit both repos separately (`wiles-source`, `wiles-public`).
5. Push both `main` branches. `git pull --rebase origin main` first if either remote has moved (the previous release's `cask(wiles): update to vX.Y.Z` commit often lands on `wiles-public/main` after you last synced).
6. Tag `wiles-source` `vX.Y.Z` and push the tag — triggers `.github/workflows/release.yml` (build → package → publish to GitHub Releases → update Homebrew Cask), fully automated from there. No local packaging/signing steps needed (the manual SHA256 checklist above is legacy/fallback only).
7. Check it started: `gh run list --repo marcops/wiles-source --limit 3`.
- **Never invent release-note content** — derive it from the actual diff/commits since the last tag (`git log vPREV..HEAD --oneline` in `wiles-source`). A version with zero user-facing commits still needs a heading but gets no Features/Bug Fixes section.

## Generic README Documentation

- The public `README.md` must remain completely generic across versions. Never hardcode version numbers in download links, titles, or release notes links — use "Latest Release" and point to `releases/latest` or `RELEASE_NOTES.md`.

## Public `RELEASE_NOTES.md` — Hard Cap of 5 Full Versions, Then Consolidate

- Applies to `marcops/wiles` (public repo) `RELEASE_NOTES.md`. At most the 5 most recent version entries stay in full detail. This is a hard cap checked every time a version is added — the moment adding a new version would exceed 5, the oldest previously-full version gets folded into the trailing consolidated section in that same edit.
- **Consolidated section** (`## Earlier Highlights`, at the bottom): one short line per version, major shipped features only — no bug fixes, security fixes, perf notes, or refinements. A version with no user-facing "New Features" section gets no line at all. Never drop a real feature line for being old — only "not a feature" is a reason to cut it.
- **Language**: plain, human language everywhere — see `WILES_UI_UX_RULES.md`'s "No Dev Jargon in User-Facing Copy". No internal/CI-only fixes with zero user-visible effect (drop those entirely), no naming competitors (Finder, GNOME/Nautilus) — describe Wiles' own behavior.
- **Trailing footer, always last**: the file always ends with a `## 💬 Feedback, Feature Requests & Bug Reports` section, after `## Earlier Highlights`, never before it.
- Why: this is public-facing marketing history, not a changelog archive — recent detail is useful to evaluate what just shipped, but a growing wall of old bug-fix bullets buries it.

## Zero Hardcoded Paths in Tests

- Never hardcode user-specific absolute directory paths or raw `"/tmp"` string literals in test files. Every temporary folder, dummy URL, or mocked file path MUST be created dynamically via `URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(...)`.
- Note: this is currently **not** lint-enforced — the existing test suite has real violations (`AppStateSmartFolderTests.swift`, `CopyPathTests.swift`, etc.) that would need cleaning up first before a mechanical check could be added safely.

## Strict 1-to-1 Test File Organization

- Every model file in `Sources/Wiles/Models/` gets its own test file in `Tests/WilesTests/Models/<ModelName>Tests.swift`; every feature in `Sources/Wiles/Features/` gets its own in `Tests/WilesTests/Features/<FeatureName>Tests.swift`. Never bundle tests for multiple models/features/sheets into one aggregated file.

## Strict Test Isolation & Zero Side-Effects

- Tests must never assume a shared singleton (e.g. `LocalHttpServerService.shared`) is in a specific initial state — query current state or restore it defensively in a `defer` block.
- Tests must never mutate real user persistence (`UserDefaults.standard`, saved smart folders, rule lists) without isolating keys or restoring original state in a guaranteed `defer` block.

## Strict UI Test Verification Standards

- Never hide interaction checks behind unasserted `if element.exists { element.click() }` — always assert/verify presence explicitly.
- `XCUIElement` queries always return non-nil query proxies — never `XCTAssertNotNil(element)` to check visibility; always evaluate `element.exists` or `element.waitForExistence(timeout:)`.
- All UI test files in `Tests/WilesUITests/` MUST be registered in `Package.swift` and run in automated test runs.

## Window-Scoped UI State in This App

Wiles supports one or more simultaneously open windows. `AppState` itself is now constructed fresh per window (in `MainContentView.init`) — only `AppState.preferences`/`.modal`/`.transient` are shared instances, passed in from `WilesApp` into every window's `AppState`. Any new field added to `AppState`, one of its per-window stores (`navigation`, `fileSystem`, `selection`, `smartFolder`), or the shared stores must be deliberately classified as either per-window or genuinely shared — never added without making that call explicitly. Getting this wrong is a real, previously-shipped bug class: a field that should be per-window but lands on a shared store fires/leaks across every open window at once (see `SWIFT_LANG_RULES.md` for the generic pattern and wiring technique this app follows to avoid it).

- Any per-window presentation state (sheets, alerts, "currently editing this item" flags) belongs on `WindowUIState`, instantiated as `@State` inside `MainContentView`. AppKit-level code reached through an `NSViewRepresentable` (custom key-event monitors, etc.) gets the per-window object threaded through as an explicit parameter, same as `AppState` already is.
- Exception: state with no natural owning window (an alert from a background auto-organization scan or network op with no UI in front of it) legitimately stays on `ModalStore`.
- Code living outside any single window's view hierarchy (menu `Commands` in `WilesApp`) reaches the focused window's `AppState`/`WindowUIState` via `@FocusedValue` — both are optional there, since no window may be focused.

## Never Hardcode the Set of Supported Locales — Applies to Every Layer Here

Beyond Swift source, a static HTML/JS asset in this app (`Sources/Wiles/Resources/SharedFolder.html`) that needs to render in the visitor's language must not embed a hand-picked subset of translations inline either — generate/populate its per-locale content from the same `.lproj` resources at build or serve time (template + placeholder substitution, per the "No Embedded Text" rule in `SWIFT_LANG_RULES.md`), so adding a new `.lproj` folder is the only step needed for every consumer of the locale list to pick it up automatically.

## AppState Facade Refactor (Context)

`AppState.swift` was split into domain stores (`navigationStore`, `preferencesStore`, `modalStore`, `selectionStore`, `fileSystemStore`), and the forwarding layer (150+ lines of computed properties like `get { navigationStore.currentURL } set { ... } }`) was removed. Stores are now exposed directly without the `Store` suffix (`appState.navigation`, `appState.preferences`, `appState.modal`, `appState.selection`, `appState.fileSystem`). Views read `appState.navigation.currentURL`, `appState.preferences.viewMode`, etc. `AppState+Preferences.swift` was deleted as dead code (a duplicate UserDefaults-restore path never called).

When adding new `AppState` properties, put them on the relevant domain store directly, unless the property is genuinely composite/cross-store.

## Locale Loop Completeness

When bulk-editing an l10n key across all Wiles locales via a shell loop, don't hand-type the locale list — it's easy to drop one (already happened, a raw untranslated key like `shortcutsAllTab` shipped to the running app). Generate the list from disk instead: `for d in Sources/Wiles/Resources/*.lproj; do ...` (or `ls Sources/Wiles/Resources | sed 's/.lproj//'`). After any bulk l10n edit, grep-count the changed key across every locale directory (not just a spot-check) and confirm the count matches the locale count.

## Never Install Tools to Solve a Problem

Don't reach for `gem install`, `brew install`, `pip install`, etc. before checking whether the repo's own tooling already handles it, or the file can be hand-edited directly. Check `scripts/`, this file, and existing config/project files first. If a file format looks like it needs tooling (pbxproj, plist, lockfiles), try direct text editing by mirroring an existing entry before adding a new dependency.

## TODO/Checklist: Delete Completed Items

In TODO/checklist files (e.g. `TODO/RESOLVE.md`), a completed item gets **deleted** entirely — never checked off (`- [x]`) and left there. The file represents only remaining work; commit history is the record of what shipped. Delete the item (and its parent section if it becomes empty) rather than checking a box.
