# UI / Untestable-Today Backlog

Items logged here per `.agents/AGENTS.md` rule 28: genuinely not unit-testable today with the
infrastructure this project has, with what's missing and why. Pull an item off this list and write
the real test the moment the missing infrastructure exists.

## `Sources/Wiles/Models/AppState/AppState+Navigation.swift`

- **`completeNavigation`'s non-directory branch (`NSWorkspace.shared.open(url)`) — removed after
  causing a real problem, not just left uncovered.**
  A test (`AppStateNavigateToFileTests`, added 2026-08-08) tried to cover this by calling
  `navigateTo()` on a real file with an extension with no registered app handler, assuming
  `NSWorkspace.shared.open` would silently no-op for an unhandled extension. It does not: macOS
  shows a real "There is no application set to open the document ... /sample.wilesnohandlertest"
  modal dialog that blocks the test run and requires a human to click it away — every `swift test`
  invocation, including CI, would hang on an unattended dialog. The test (and its registration in
  `WilesAutomatedXCTestCase.swift`/`AutomatedTestService.swift`) was deleted rather than left in.
  There is no dependency-injection seam to fake "this file was opened" without a source change.
  - *Source change that would fix this (NOT made — reported per hard rule 2):* extract the
    `NSWorkspace.shared.open(url)` call behind an injectable provider (e.g. a
    `fileOpener: (URL) -> Void` closure property on `AppState`, defaulting to the real
    `NSWorkspace` call in production, overridable in tests to just record the URL it was called
    with). With that seam, the branch itself (does it correctly skip updating `currentURL`/history/
    selection for a non-directory target) becomes testable without ever touching the real OS.

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

## `Sources/Wiles/Services/LocalizationService.swift`

- **`L10n.activeCode(_:)`'s final `return "en"` fallback (lines 54-55) — only reached when `.system`
  is passed and none of `Locale.preferredLanguages` (the real host machine's actual language list)
  match any supported `AppLanguage` code.** There is no injectable seam to override
  `Locale.preferredLanguages` from a test, and every dev/CI machine's real locale list is virtually
  guaranteed to include a match (English is always present as a fallback in the real system list).
  - **Why it's out of scope now**: would require either mocking `Locale` (no such abstraction exists
    in this file) or running the test suite under a real macOS user account configured with zero
    supported-language preferences — not reproducible/controllable from `swift test`. A `Sources/`
    change (e.g. an injectable `preferredLanguagesProvider: () -> [String]` static var) would fix
    this but was not made per hard rule 2.

- **`L10n.resourceBundle`'s three candidate-bundle-resolution branches (lines 66-80) — only one
  branch executes per process, and which one is entirely determined by the real
  `Bundle.main.resourceURL`/`Bundle.main.bundleURL` filesystem layout at test-run time, not by
  anything a test controls.** `resourceBundle` is a `static let`, computed exactly once and cached
  for the life of the process, so no sequence of test calls can force a different branch within the
  same `swift test` invocation.
  - **Why it's out of scope now**: same class of limitation as the `SidebarItem`/`NetworkShare`
    default-value attribution note above — not a missing test, a property of how the code is
    structured. Forcing coverage of all three branches would require a `Sources/` change (injecting
    the bundle-resolution strategy) requiring approval.

- **`L10n.string(_:lang:)`'s final generic fallback (line 89, `return
  resourceBundle.localizedString(...)` after the `if let path = ... , let langBundle = ...` lookup
  fails) — unreachable through any current public `AppLanguage` case.** Every non-`.system`
  `AppLanguage` case has a matching `<code>.lproj`/`<code.lowercased()>.lproj` folder actually
  bundled under `Sources/Wiles/Resources/` (verified: ar, de, en, es, fr, it, ja, ko, nl, pl, pt, ru,
  sv, tr, zh-Hans all present), so the two-step lookup on lines 85-86 always succeeds for every real
  input `L10n.string` can be called with.
  - **Why it's out of scope now**: this is defensive dead code for a "resource bundle is missing an
    lproj for a currently-supported language" scenario that can't be synthesized without either (a)
    adding a bogus `AppLanguage` case with no matching `.lproj` folder (a `Sources/` change) or (b)
    corrupting the real compiled resource bundle at test time (would break every other localization
    test sharing the same process). Confirmed unreachable via all 15 non-system `AppLanguage` cases.

## `Sources/Wiles/Models/FolderNode.swift`

- **`loadSubfolders(at:autoExpandFor:)`'s `guard let urls = try? fm.contentsOfDirectory(...) else {
  return [] }` failure branch (line 21).** `loadSubfolders` is `private`, so `@testable import` does
  not expose it directly to `FolderNodeTests` — the only entry point is the public
  `FolderNode.buildRootTree()`, which always starts enumeration at the real filesystem root `/` and
  recurses only into real ancestor directories of the real current user's home directory. Hitting
  this branch would require one of those real directories to fail `contentsOfDirectory` (e.g. a
  permission-denied directory on the path from `/` to `~`), which isn't something a test can
  reliably construct or control on a real macOS install without mutating real system directory
  permissions — an unacceptable side effect outside the sandboxed temp directories this suite
  otherwise confines itself to.
  - **Why it's out of scope now**: no injectable seam (e.g. an injected `FileManager`/directory-lister
    abstraction) exists to substitute a fake failing listing. Adding one would be a `Sources/` change
    requiring approval.
## `Sources/Wiles/Services/UndoRedoService.swift`

- **`UndoRecord.id` (`= UUID()`) and `UndoRecord.timestamp` (`= Date()`) stored-property default
  initializers — show 0% coverage in `llvm-cov`'s per-function breakdown despite `UndoRecord` being
  constructed 70+ times across `UndoRedoTests` (every `recordAction(_:)` call constructs one via the
  synthesized memberwise `init(actionType:)`, which evaluates both defaults every time).** This is
  the same attribution quirk already documented for `AppState.perFolderViewModes` in this file: LLVM
  credits the outlined default-value initializer symbol (`...UndoRecordV2id...vpfi`,
  `...timestamp...vpfi`) separately from the call site that evaluates it inline, and the outlined
  copy itself is never directly invoked at `-Onone`. No test can force that outlined symbol to run
  independently of the constructor call it's inlined into — there is no missed *behavior* here, just
  a tooling artifact. Not chasing further.

## `Sources/Wiles/Features/ArchiveInspector/ArchiveInspectionService.swift`

- **`listEntries(in:)` — the `guard let output = String(data: data, encoding: .utf8) else { return
  [] }` failure branch.** Reaching the `else` requires `/usr/bin/unzip -Z1`'s stdout to contain bytes
  that are not valid UTF-8, which in practice only happens for an archive holding an entry name
  encoded in a legacy non-UTF-8 codepage (e.g. classic Mac OS Roman / CP437 filenames from a
  pre-UTF-8-era zip). Neither `ditto` nor `/usr/bin/zip` (the only compression paths this app uses)
  provide a supported, non-fragile way to author such an entry name from a Swift test — doing so
  would mean hand-crafting raw zip central-directory bytes, which is disproportionate to the one
  defensive branch it covers and would be brittle against `unzip` version differences. Left
  uncovered; all reachable branches around it (empty output, corrupt archive, missing archive,
  nested/deep/special-character entries) are covered in `ArchiveInspectionTests`.

## `Sources/Wiles/Services/SpotlightSearchService.swift`

- **`queryDidFinishGathering(_:)` — the `guard let query = metadataQuery else { return }` false
  branch, and the `for i in 0..<count` loop body (the `if let item = ... as? NSMetadataItem, let path
  = ...` positive path).** Both require a real `NSMetadataQuery` gathering notification to fire with
  the service in a specific internal state (`metadataQuery` already `nil`, or a query that actually
  returned indexed results) — there is no injectable seam to fake `NSMetadataQuery` itself (it's a
  sealed AppKit/Foundation class, not mockable), and `queryDidFinishGathering(_:)` is `private`, so
  `@testable import` cannot invoke it directly to synthesize either state. Driving this through the
  real Spotlight index depends on the local machine's indexing state and cold-start latency, which is
  independent of whether the target file is actually indexed — this is the same flakiness class
  already called out for `testSpotlightSearchWithRealResultsPopulatesURLs` in `SpotlightSearchTests`
  (softened to avoid a tight-timeout non-empty-results assertion). Reintroducing a test that depends
  on real Spotlight returning at least one result within the 1.5s per-test budget would reproduce
  that same flakiness. Left uncovered; the empty-query short-circuit, `stopSearch()`'s both branches,
  and the apostrophe/predicate-injection regression are all covered in `SpotlightSearchTests`.
## `Sources/Wiles/Services/AutoOrganizationService.swift`

- **`processFolder()`'s move-failure `catch` block (line 156, comment-only body)**, hit only when
  `FileSystemService.moveItem(at:toFolder:)` throws inside the detached move task. Not attempted: a
  destination folder that doesn't exist would make `moveItem` throw deterministically, but
  `AutoOrganizationTests.swift` already keeps a heavily reused `service`/`targetDir` pair across many
  sequential sub-tests in one `run()`, and this file's total runtime (~4.7s) is already flagged in
  `.agents/AGENTS.md`-adjacent guidance as the slowest suite in the project — adding another
  `Task.detached` + 150ms stability-check + settle-time wait (the same pattern every other
  `processFolder` test here already needs) was judged not worth the additional wall-clock cost for
  one comment-only line already proven exercised via the identical logic path in
  `testGrowingFileIsNotMoved`'s "still being written" branch just above it. Coverage is at 99.44%
  lines / 100% functions for this file; only this one branch remains.

## `Sources/Wiles/Features/HttpSharing/LocalHttpServerService.swift`

Remaining gaps after adding `testDirectoryRemovedAfterStartReturns500`,
`testMalformedPercentEncodingReturnsBadRequest`, `testEmptyConnectionContentIsClosedSafely`, and
`testNonUtf8ConnectionContentIsClosedSafely` to `LocalHttpServerServiceTests.swift`:

- **`stateUpdateHandler`'s `default: break` branch (line 36)**, hit only when the listener enters
  `.setup`/`.waiting`/`.preparing` instead of going straight to `.ready`. Tried: pre-occupying port
  8080 with a raw BSD socket (both `AF_INET` and `AF_INET6` wildcard binds, confirmed both bound
  successfully) before calling `start(sharing:)`, expecting the service's own `NWListener` to sit in
  `.waiting`. Empirically verified this does **not** work: `server.isRunning` still becomes `true` —
  `NWListener`/`Network.framework` apparently sets `SO_REUSEPORT` (or equivalent) by default, so a
  second listener binds successfully alongside the occupying socket instead of waiting. No other
  in-process way to force a `.waiting`/`.preparing` state was found without a real second contending
  process holding the port exclusively, which isn't reproducible/deterministic in a unit test.

- **`start()`'s `catch { stop() }` branch (line 47)**, hit only if `NWListener(using:on:)` throws
  synchronously. With this file's fixed `NWParameters.tcp` and a `port` that's already typed as the
  validated `NWEndpoint.Port` (construction of an invalid port value isn't possible through the
  public API used here), there's no reachable input that makes this initializer throw — port
  conflicts and bind failures surface asynchronously via the `.failed` listener state instead
  (already covered by other means/branches), not as a thrown error.

- **`updateServerURL()`'s no-`en0`-interface fallback (lines 98-99, `finalServerURL =
  "http://localhost:..."`)**. This only executes when `getifaddrs()` finds no `en0` interface with
  an `AF_INET` address — environment-dependent (Wi-Fi/Ethernet must be down or absent). Every dev
  machine and CI runner this suite has run on has an active `en0`, so the positive branch (line 96)
  is the only one naturally reachable; forcing the negative branch would require actually disabling
  networking during the test run, which is out of scope for a unit test.

- **`processRequest()`'s `guard let firstLine = lines.first` failure branch (lines 129-130)**.
  Structurally unreachable: `String.components(separatedBy:)` always returns an array with at least
  one element (splitting `""` yields `[""]`), so `.first` can never be `nil` here. Dead defensive
  code, not something a test can exercise without a `Sources/` change.

- **`processRequest()`'s `guard let folder = sharedFolder` failure branch (lines 142-143)**. Only
  reachable if a request is processed after `sharedFolder` has been cleared but before the listener
  has actually stopped accepting/reading connections — `stop()` sets `sharedFolder = nil`
  synchronously while `listener?.cancel()` and any in-flight `connection.receive` completions race
  independently on the service's private serial queue. There's no public hook to pause the listener
  mid-request or to inject a request between those two points deterministically; any attempt would
  depend on exact scheduling of GCD callbacks and would be flaky.

- **`streamFile()`/`sendNextChunk()`'s `connection.send` failure branches (lines 220-223,
  244-247)**, hit only when writing the response back to the client itself fails (e.g. client resets
  the connection mid-transfer). Tried: opening a raw socket, sending a `GET` for an existing file,
  then immediately closing the socket without reading the response, hoping to induce a write error
  on the server's next `send(content:completion:)` call. On localhost this raced unpredictably —
  sometimes the full response was already flushed into the kernel socket buffer before the client's
  `close()` took effect, so the server's send completion still reported no error. Left out rather
  than shipping a test that passes or fails depending on scheduling.
## `Sources/Wiles/Services/PermissionService.swift`

- **`openFullDiskAccessSettings()` (lines 7-11) — entirely uncovered.**
  Calls `NSWorkspace.shared.open(url)` with an `x-apple.systempreferences:` deep link. Actually
  invoking it in an automated `swift test` run would open the real System Settings app on the test
  machine — a real, visible side effect on the developer's/CI machine with no way to close it from
  the test process. This is exactly the class of risk called out in the task's hard rule 3 (do not
  trigger real system UI a human would need to dismiss). Only the well-formedness of the deep-link
  URL string itself is verified (`PermissionTests.testSettingsDeepLinkURLComponents()`).

- **`probeProtectedFolders()` (lines 23-28) — entirely uncovered.**
  Private, only reachable through `requestInitialPermissions(language:)`'s "not yet shown" branch
  (see below) — it cannot be called directly from a test. Reaching it therefore requires accepting
  the same blocking-alert risk described below.

- **`requestInitialPermissions(language:)`'s "not yet shown" branch (lines 37-49) — uncovered.**
  Only the early-return "already shown" guard (line 36) is exercised. The rest of the function is
  gated behind `!defaults.bool(forKey: hasShownFullDiskAccessPromptKey)` **and** — once past that —
  `!hasFullDiskAccess()`. `hasFullDiskAccess()` checks real readability of
  `/Library/Application Support/com.apple.TCC/TCC.db`, which this sandboxed test environment does
  not have (verified directly: `test -r ".../TCC.db"` → not readable). That means any test run here
  that clears the "already shown" flag and calls `requestInitialPermissions()` deterministically
  falls into the `NSAlert().runModal()` branch (lines 41-48) — a real, blocking system alert that
  needs a human click to dismiss. This is the literal scenario flagged in the task's hard rule 3
  ("NSWorkspace.shared.open() on files with racy cleanup triggered a blocking file-not-found system
  alert" — same failure class, different trigger). Not forced.
  - *Source change that would fix this (NOT made — reported per hard rule 2):* extract
    `hasFullDiskAccess()`'s TCC.db-readability check behind an injectable provider (e.g. a
    `fullDiskAccessChecker: () -> Bool` closure property on `PermissionService`, defaulting to the
    real check in production, overridable in tests to force the "already has FDA" path). With that
    seam, the "not yet shown + already has FDA" path (set flag, probe folders, return without
    showing the alert) becomes fully deterministic and safe to test. The alert-showing path itself
    would still need a human or a UI-automation harness (not present in this suite) to dismiss
    `NSAlert.runModal()`, so it would remain backlogged even with the seam.

## `Sources/Wiles/Views/Content/FileColumnView.swift`

- **`.onChange(of: appState.fileSystem.items)` row-sync handler (added 2026-08-08) — uncovered.**
  Column view keeps its own local `columns: [ColumnData]` snapshot per drilled-into folder instead
  of rendering `appState.fileSystem.items` directly like Grid/List do. This handler re-syncs
  whichever local column matches `appState.navigation.currentURL` whenever `fileSystem.items`
  changes, fixing a bug where pasting/creating/deleting a file while Column view was active and
  `currentURL` didn't change (e.g. paste into the currently-open folder) silently didn't appear
  until the user re-navigated. The closure lives inline in `FileColumnView`'s SwiftUI `body` — there
  is no seam to invoke it directly from `WilesTests` (no ViewInspector or XCUITest harness in this
  suite), so its branch (finding the matching column index, updating `.items`) can't be exercised as
  a pure function today. No dependency-injection change would fix this without either adopting a
  UI-inspection test library or extracting the sync logic into a testable free function that the
  view merely calls (the latter is a reasonable follow-up if this class of Column-view bug recurs).

## `Sources/Wiles/Models/AppState/AppState+Operations.swift`

- **`downloadFromiCloud(url:)`'s success path (lines 9-11, the `await MainActor.run { self?.refreshCurrentDirectory() }` inside the `try` branch) — uncovered.**
  The failure path (`FileManager.default.startDownloadingUbiquitousItem(at:)` throwing for a URL
  that isn't a ubiquitous item) is covered
  (`AppStateOperationsExtraTests.testDownloadFromiCloudFailure()`). Reaching the success path
  requires a URL that macOS's `FileManager` actually recognizes as a ubiquitous (iCloud Drive)
  placeholder item — there's no local/offline way to fabricate one, and whether this test machine
  even has an iCloud Drive container configured/signed-in is environment-dependent and outside this
  suite's control. No dependency-injection seam exists to fake "this URL is ubiquitous" without a
  source change. Left uncovered rather than depending on real iCloud account state.
