## High priority (broken or inconsistent core functionality)
 revisar todos os testes que damos skip no ci

 
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