# UI / Untestable-Today Backlog

Items logged here per `.agents/AGENTS.md` rule 28: genuinely not unit-testable today with the
infrastructure this project has, with what's missing and why. Pull an item off this list and write
the real test the moment the missing infrastructure exists.

## `Sources/Wiles/Models/AppState/AppState.swift`

- **`performEmptyTrash()` (lines 261-292) — entirely uncovered.**
  Hardcodes `FileManager.default.urls(for: .trashDirectory, in: .userDomainMask)`, i.e. the real
  macOS user's actual `~/.Trash`. There is no dependency-injection seam to point it at a fake/test
  trash directory. Calling this function for real in a unit test would permanently and irreversibly
  delete every item currently in the developer's/CI machine's real Trash — an unacceptable
  destructive side effect (violates rule 17's "zero real state contamination" spirit even though
  that rule is phrased around `UserDefaults`). **Not tested, and should not be tested as-is.**
  - *Source change that would fix this (NOT made — reported per hard rule 2):* extract the trash
    directory lookup behind an injectable provider (e.g. a `trashDirectoryProvider: () -> URL?`
    closure property on `AppState`, defaulting to the current `FileManager` lookup in production,
    overridable in tests to point at a throwaway temp directory). The same seam would also let
    `updateTrashSize()`'s enumeration loop (see below) be exercised deterministically.

- **`updateTrashSize()` enumeration loop body (lines 244-251) — partially uncovered (the loop's
  `while let fileURL = enumerator.nextObject()` body never executes an iteration).**
  This walks the same real `~/.Trash` as above. The loop body only runs if the real Trash actually
  contains at least one item at test-run time, which isn't something a test can control without
  either (a) writing files into the developer's/CI's real Trash (same destructive-contamination
  problem as `performEmptyTrash()` — those files would sit in Trash indefinitely, and there's no
  reliable way to guarantee cleanup since the enumeration/deletion path itself is what's under test),
  or (b) the same trash-directory injection seam described above. Left uncovered rather than
  polluting real user state.
  - The two early-return guards right above it (`trashURL == nil`, `enumerator == nil`, lines
    235-236 and 241-242) are also uncovered and are effectively unreachable on any real macOS
    install — `FileManager` always resolves `.trashDirectory` and always returns a non-nil
    enumerator for an existing directory. Same injection seam would make these testable too (inject
    a provider that returns `nil`, or a URL that FileManager can't enumerate).

- **`AppState.perFolderViewModes` property initializer's `?? [:]` fallback closure — shows 0%
  coverage in `llvm-cov`'s per-function breakdown despite running on every `AppState()`
  construction when `UserDefaults` has no `perFolderViewModes` key yet.** This looks like an
  attribution quirk of how `llvm-cov` credits a stored property's default-value autoclosure inside
  a class initializer, not a real gap in exercised behavior (the surrounding line/property is fully
  exercised — dozens of `AppState()` constructions happen across the suite). Not chasing further;
  flagging in case it recurs for other properties with `UserDefaults ... ?? default` initializers.

## `Sources/Wiles/Services/OpenWithService.swift`

- **`open(urls:with:)` — non-empty urls branch (the body after `guard !urls.isEmpty else { return }`).**
  Calls the real `NSWorkspace.shared.open(urls, withApplicationAt:configuration:completionHandler:)`,
  which is asynchronous and dispatches its actual file lookup after the call returns. A test can't
  safely provide a real target file and then clean it up (even via `defer`) without racing that
  async lookup — if the file is gone by the time NSWorkspace processes the request, macOS presents a
  real, blocking "file not found" system alert that requires a human to dismiss it, hanging any
  automated run. There is no completion-handler-based way to await/verify the call finished first.
  - **Why it's out of scope now**: no safe way to test this branch without either leaking temp files
    permanently (never cleaning up, so a future async open can't race a deletion) or refactoring
    `OpenWithService.open` to accept an injectable workspace/opener abstraction — a `Sources/` change
    requiring approval. The empty-urls guard branch is already covered by
    `OpenWithTests.testOpenWithEmptyURLsIsNoOp` equivalent (`open(urls: [], with:)` case in
    `OpenWithTests.run()`).

- **`chooseOtherApplication(toOpen:)` — non-empty urls branch (lines 59-71, the body after the
  `guard !urls.isEmpty else { return }`).**
  This branch constructs a real `NSOpenPanel` and calls `panel.begin { ... }`. There is no
  dependency-injection seam to swap in a fake panel, and actually invoking it in an automated
  `swift test` run presents a real, interactive system panel with no guaranteed way to dismiss it —
  that risks hanging the test run indefinitely (violating the 1.5s-per-test budget) or behaving
  nondeterministically in a headless/CI environment with no window server interaction.
  - **Why it's out of scope now**: no UI automation harness in this suite drives real `NSOpenPanel`
    interaction (the closest precedent, `WilesUITests`, drives the app's own SwiftUI views via
    accessibility, not system-owned AppKit panels). The empty-urls guard branch (the only
    deterministic, side-effect-free path) is already covered by
    `OpenWithTests.testChooseOtherApplicationWithEmptyURLsIsNoOp()`.

## `Sources/Wiles/Services/NetworkDiscoveryService.swift`

- **Real Bonjour/mDNS discovery callback (lines 38-40, `browseResultsChangedHandler` closure body;
  lines 53-65, `updateDiscoveredShares(from:)`).**
  `updateDiscoveredShares` is `private` and is only ever invoked from `NWBrowser`'s
  `browseResultsChangedHandler`, which only fires when the real system Bonjour/mDNS stack observes
  actual `_smb._tcp` services on the local network. `NWBrowser.Result` and its `.service` endpoint
  case have no public initializer, so there is no way to synthesize fake browse results from a unit
  test, and the service exposes no injection point (e.g. a protocol-wrapped browser) to substitute a
  fake implementation.
  - **Why it's out of scope now**: exercising this code path deterministically would require either
    (a) real SMB-advertising peers reachable on whatever network CI/dev machines run on — not
    guaranteed and not repeatable — or (b) refactoring `NetworkDiscoveryService` to accept an
    injected browser/result-source abstraction, which is a `Sources/` change requiring approval.
    Every other branch in this file (init, `startBrowsing` idempotency guard, `stopBrowsing`,
    `NetworkShare` itself, and its sorting) is already covered by `NetworkDiscoveryTests`.

## `Sources/Wiles/Models/SidebarItem.swift`

- **Synthesized memberwise-initializer default value (line 4, `let id = UUID()`).**
  `SidebarItem` has no explicit `init`, so Swift synthesizes its memberwise initializer (excluding
  `id`, which carries a default value). `SidebarItemTests` already constructs multiple `SidebarItem`
  instances and asserts their `id`s differ, so the default-value expression on line 4 genuinely
  executes on every construction — but `llvm-cov` does not attribute coverage counts to a
  stored-property default-value expression when it's only reached through a compiler-synthesized
  (not user-written) initializer. Confirmed by contrast: `NetworkShare` in
  `NetworkDiscoveryService.swift` has the identical `let id = UUID()` pattern but *does* show as
  covered, because `NetworkShare` has an explicit user-written `init(name:url:)` — the same default
  value expression is instrumented there.
  - **Why it's out of scope now**: this is a coverage-tooling limitation, not a missing test. The
    only way to make line 4 show as covered would be to give `SidebarItem` an explicit `init`, which
    is a `Sources/` change requiring approval.
