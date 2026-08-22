## High priority (broken or inconsistent core functionality)
 revisar todos os testes que damos skip no ci
- revisar o validate se tem tudo no CI
 
- CI-only test failure to fix once CI is stable: `AppStateFavoritesMoveTests.testMoveItemUpdatesFavorites`
  ("POS: moveItem() updates the favorite to the real new on-disk location, not just the old stale path")
  fails on every GitHub Actions run but passes every time locally (RAM disk or not), same class of
  Foundation/SDK-version difference as the PermissionTests deep-link bug (see commit 1a57fce) but no
  confirmed root cause yet. Currently marked `SKIP-CI-SLOW`-style in `WilesAutomatedXCTestCase.swift`
  (`grep -rn "SKIP-CI" Tests/` finds it). Investigate `FileSystemService.moveItem`'s non-standardized
  `destURL` construction and `AppState.remapFavorites`'s `.standardizedFileURL` comparison for a
  CI-toolchain-specific symlink-resolution or idempotency quirk.

- CI-only test failure to fix once CI is stable: `FileShredderTests.runMidOverwriteCancellationCoverage`
  ("POS: shredFiles() honors Task.isCancelled inside the overwrite loop for a large file and stops
  mid-write") assumes a 50MB overwrite is still in progress 1ms after starting, so cancelling then
  reliably lands mid-write. On the RAM disk that write can finish inside 1ms, so the operation
  sometimes completes before cancellation is requested. Can't fix by enlarging the test file (would
  exceed the 100MB RAM disk) - needs a deterministic signal that the overwrite loop has started
  (e.g. a testable progress hook) instead of a fixed delay guess. `grep -rn "SKIP-CI" Tests/` finds it.

- CI-only build crash (v0.3.10 release runs, `macos-15` runner, 2026-08-22): the "Unit tests
  (WilesTests, RAM-backed scratch disk)" step fails with a bare `error: fatalError` and no
  file/line/assertion — before any test actually runs. Passes clean locally via `validate.sh` (same
  `swift test --filter WilesTests` command). Not an `XCTSkip`-able case like the entries below since
  it's a compile-time crash for the whole target, not a specific test. **Currently disabled in
  `release.yml`** via `continue-on-error: true` (marked `SKIP-CI-ENV`) so releases aren't blocked;
  `validate.sh` locally remains the real gate.
  Three attempts, all failed identically (nothing ever reached "Build & package"):
  1. Baseline: crashed at `[330/335] Compiling Wiles resource_bundle_accessor.swift`.
     https://github.com/marcops/wiles-source/actions/runs/32586497178 (and a retry with no changes,
     same result: https://github.com/marcops/wiles-source/actions/runs/32586913685).
  2. Pinned Xcode to 26.3 (`xcode-select -s`) to match local toolchain (local is Swift 6.3.3,
     macOS 26 — the runner's default is Xcode 16.4, confirmed via the `macos-15` runner-image docs,
     which also lists 26.0.1/26.1.1/26.2/26.3 as installed options): still crashed, same position
     (330/335), different nominal file (`FolderPickerTarget.swift`).
     https://github.com/marcops/wiles-source/actions/runs/32587072256
  3. Reverted the Xcode pin, throttled to `swift test --jobs 2` (resource-exhaustion theory, since
     the crash lands at the same *position* in the file count regardless of toolchain/which file is
     nominally compiling): still crashed, same position, same file as attempt 1.
     https://github.com/marcops/wiles-source/actions/runs/32587203473
  The "always position 330 of 335" pattern across all three runs is the strongest lead, but
  reducing parallelism should have helped if it were memory pressure and didn't, so that theory is
  now in doubt too. Needs a verbose (`-v`) capture of the actual crash to make progress — not
  something to keep guessing at with full release runs.

- `git-beacon-mac` dependency drift: its `0.0.2` git tag on GitHub had moved to a different commit
  than `Package.resolved` had pinned, which broke any fresh dependency resolution (new CI runner,
  clean local `.build`) with a revision-mismatch error. Worked around by updating `Package.resolved`
  to the tag's current commit (`9e66de88...`, was `32ea1ba8...`) so builds succeed again - still worth
  finding out why the tag moved on the git-beacon-mac side, in case it wasn't intentional.

- All tests currently skipped in CI (`grep -rn "SKIP-CI" Tests/` finds every one below):
  - **SKIP-CI-CRASH** (real LaunchServices/NSWorkspace calls crash the whole test process on GitHub
    Actions runners - permanent, not expected to ever run in CI): `testOpenWithTests`,
    `DefaultFolderHandlerServiceTests.testRegisterAsFolderHandlerOptionInvokesCompletionExactlyOnce`,
    `DefaultFolderHandlerServiceTests.testRegisterAsFolderHandlerOptionWithDefaultCompletionDoesNotCrash`.
  - **SKIP-CI-SLOW** (took over 2s locally, skipped in CI by policy to keep the pipeline fast - still
    run locally via `validate.sh`, not otherwise broken): `testArchiveTests`, `testHttpServerTests`,
    `testAutoOrganizationTests`, `testAppStateOperationsExtraTests`, `testDirectoryMonitorTests`.
  - **SKIP-CI-ENV** (fails only on CI's toolchain/environment, unconfirmed root cause - the two
    entries above this one, `AppStateFavoritesMoveTests.testMoveItemUpdatesFavorites` and
    `FileShredderTests.runMidOverwriteCancellationCoverage` - these are the ones actually worth
    revisiting, the CRASH/SLOW ones above are working as intended).