## Bugs

- Committed secret — `Constants/CrashReportingConstants.swift:15`. `github_pat_...` token hardcoded, compiled into the binary. Not rotated yet (deliberately left as-is for now).

## Low priority / undecided

-  o gridview tem que mostrar 2 linhas igual o ifinder se o texto for muito grande, e se for maior que isto ai sim coloca os 3 ppontos
- terminal com follow mode, ou seja segue a pasta que eu esotu no folder ou vice e versa, a pasta que eu estou navegando no terminal.
- hide the back and forward, and increase the Title font? with on/off
- create the director view and traditional view?
- permite remover todos os itens do sidebar mas ele segue ali

- zip feature
Double-clicking a `.zip` file should open it in-place the same way a real folder does (reusing whichever view mode is active — Grid/List Column) and let the user navigate inside it normally. Double-clicking a file *inside* that zip should extract it to a temporary location and open it (like macOS does when peeking inside a `.app` bundle).

Once this lands, the existing "Inspect Archive" context-menu sheet (`ArchiveInspectionSheetView`) becomes redundant and should be removed — this feature absorbs it.
