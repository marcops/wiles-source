## High priority (broken or inconsistent core functionality)

- CI-only test failure to fix once CI is stable: `AppStateFavoritesMoveTests.testMoveItemUpdatesFavorites`
  ("POS: moveItem() updates the favorite to the real new on-disk location, not just the old stale path")
  fails on every GitHub Actions run but passes every time locally (RAM disk or not), same class of
  Foundation/SDK-version difference as the PermissionTests deep-link bug (see commit 1a57fce) but no
  confirmed root cause yet. Currently marked `SKIP-CI-SLOW`-style in `WilesAutomatedXCTestCase.swift`
  (`grep -rn "SKIP-CI" Tests/` finds it). Investigate `FileSystemService.moveItem`'s non-standardized
  `destURL` construction and `AppState.remapFavorites`'s `.standardizedFileURL` comparison for a
  CI-toolchain-specific symlink-resolution or idempotency quirk.

- o smartfolder nao esta funcionando corretamente.

- Multi-select in Column view —  Not done. FileColumnView.swift's selectItem (line 299-300) always does appState.selectedURLs = [item.url], ignoring Cmd/Shift modifiers — it never routes through the shared AppState.handleSelection(for:) that List/Grid use. Marquee/rectangle drag-select is also entirely absent from Column view (no SelectionRectangleOverlay).

- regras de organização não deixa selecionar qualquer pasta apenas as principais (ex: download, documentos e etc) tem que deixar so a arvore direto, sem aquele favoritos , e a arvore inteira nao esta limitada que tem hje

## Medium priority (meaningful feature/UX work)

- se eu quero mover 1 arquivo o PATH BAR tem que abrir, e eu posso entrar dai nos diretorios ir direto para 1 deles.

- zip feature
Double-clicking a `.zip` file should open it in-place the same way a real folder does
(reusing whichever view mode is active — Grid/List/Column) and let the user navigate
inside it normally. Double-clicking a file *inside* that zip should extract it to a
temporary location and open it (like macOS does when peeking inside a `.app` bundle).

Once this lands, the existing "Inspect Archive" context-menu sheet
(`ArchiveInspectionSheetView`) becomes redundant and should be removed — this feature
absorbs it.

- por o validate no CI

- o gridview tem que mostrar 2 linhas igual o ifinder se o texto for muito grande, e se for maior que isto ai sim coloca os 3 ppontos

## Low priority / undecided

- hide the back and forward, and increase the Title font? with on/off

- create the director view and traditional view?
