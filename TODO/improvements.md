## High priority (broken or inconsistent core functionality)

- Multi-select in Column view —  Not done. FileColumnView.swift's selectItem (line 299-300) always does appState.selectedURLs = [item.url], ignoring Cmd/Shift modifiers — it never routes through the shared AppState.handleSelection(for:) that List/Grid use. Marquee/rectangle drag-select is also entirely absent from Column view (no SelectionRectangleOverlay).

- regras de organização não deixa selecionar qualquer pasta apenas as principais (ex: download, documentos e etc) tem que deixar so a arvore direto, sem aquele favoritos , e a arvore inteira nao esta limitada que tem hje

## Medium priority (meaningful feature/UX work)

- se eu quero mover 1 arquivo o PATH BAR tem que abrir, e eu posso entrar dai nos diretorios ir direto para 1 deles.

- o gridview tem que mostrar 2 linhas igual o ifinder se o texto for muito grande, e se for maior que isto ai sim coloca os 3 ppontos

## Low priority / undecided

- AppState tem varios campos transientes soltos direto na classe (refreshTask, trashSizeTask,
  lastOpportunisticTrashSizeCheck, suppressColumnStatePersistence, clipboard, isTrashUpdating,
  trashSizeString, etc.) que nunca vao pro UserDefaults — nao fazem parte de Preferences nem de
  nenhum outro Store existente. Auditar e agrupar isso num Store dedicado (tipo SmartFolderStore,
  que ja segue esse padrao), separado do que realmente persiste. separar o que eh storage e o que eh transiente
- hide the back and forward, and increase the Title font? with on/off
- create the director view and traditional view?
- permite remover todos os itens do sidebar mas ele segue ali
- revisar o validate se tem tudo no CI
- zip feature
Double-clicking a `.zip` file should open it in-place the same way a real folder does
(reusing whichever view mode is active — Grid/List/Column) and let the user navigate
inside it normally. Double-clicking a file *inside* that zip should extract it to a
temporary location and open it (like macOS does when peeking inside a `.app` bundle).

Once this lands, the existing "Inspect Archive" context-menu sheet
(`ArchiveInspectionSheetView`) becomes redundant and should be removed — this feature
absorbs it.
