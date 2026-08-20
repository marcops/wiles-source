## Bugs

- Navigation state (`currentURL` + back/forward history on `NavigationStore`) is still global on the shared `AppState` instead of per-window on `WindowUIState` — navigating in one open window's folder view (or its terminal, via the existing `cd`-on-navigate sync) moves every other open window too. Same bug class `WILES_RULES.md`'s "Window-Scoped UI State in This App" rule already fixed for sheets/alerts/HUDs, just never applied to navigation itself. 26 files read `appState.navigation.*`/call `appState.navigateTo(...)`, so this is a real refactor, not a one-line fix.

## Low priority / undecided

-  o gridview tem que mostrar 2 linhas igual o ifinder se o texto for muito grande, e se for maior que isto ai sim coloca os 3 ppontos
- terminal com follow mode, ou seja segue a pasta que eu esotu no folder ou vice e versa, a pasta que eu estou navegando no terminal.
- hide the back and forward, and increase the Title font? with on/off
- create the director view and traditional view?
- permite remover todos os itens do sidebar mas ele segue ali

- zip feature
Double-clicking a `.zip` file should open it in-place the same way a real folder does (reusing whichever view mode is active — Grid/List Column) and let the user navigate inside it normally. Double-clicking a file *inside* that zip should extract it to a temporary location and open it (like macOS does when peeking inside a `.app` bundle).

Once this lands, the existing "Inspect Archive" context-menu sheet (`ArchiveInspectionSheetView`) becomes redundant and should be removed — this feature absorbs it.
