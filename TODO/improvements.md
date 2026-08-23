## Low priority / undecided

-  o gridview tem que mostrar 2 linhas igual o ifinder se o texto for muito grande, e se for maior que isto ai sim coloca os 3 ppontos
- hide the back and forward, and increase the Title font? with on/off
- create the director view and traditional view?

- zip feature
Double-clicking a `.zip` file should open it in-place the same way a real folder does (reusing whichever view mode is active — Grid/List Column) and let the user navigate inside it normally. Double-clicking a file *inside* that zip should extract it to a temporary location and open it (like macOS does when peeking inside a `.app` bundle).

Once this lands, the existing "Inspect Archive" context-menu sheet (`ArchiveInspectionSheetView`) becomes redundant and should be removed — this feature absorbs it.

- `FileShredder` não tem sheet própria (é só um serviço, diferente de toda feature irmã). 
passwordCompressSheetView/DuplicateCleanerSheetView: um sheet com a lista dos arquivos selecionados a apagar, uma escolha de método (rápido/sem sobrescrever vs. seguro/sobrescrevendo N vezes — o FileShredderService já tem essa lógica de chunk overwrite), um aviso claro de "isso é irreversível", barra de progresso durante o shred (arquivo grande pode demorar), e confirmação final antes de rodar — seguindo o ModalScaffoldView que todas as outras features já usam.
A troca é: mais fricção (um passo a mais antes de apagar) vs. mais segurança visual pra uma ação destrutiva e irreversível — hoje ela roda sem nenhuma tela intermediária. Quer que eu desenhe isso como plano antes de codar, ou é só curiosidade por enquanto?

- Committed secret — `Constants/CrashReportingConstants.swift:15`. `github_pat_...` token hardcoded, compiled into the binary. Not rotated yet (deliberately left as-is for now).



### Constants/CrashReportingConstants.swift
- **[SECURITY]** Line 15 hardcodes a live-looking GitHub Personal Access Token (`githubToken = "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"`) directly in committed Swift source. Even scoped to `Issues: Read and write` on one repo, a committed PAT is a credential leak the moment this repo is public or the token isn't rotated/revoked — move it out of source entirely (environment variable, Keychain, or a git-ignored local config file loaded at runtime) and **revoke/rotate the current token now since it has already been committed to history**.

Security/data-loss bugs (BUG.md) — do these regardless of everything else: rotate the PAT, fix the LocalHttpServerService symlink path-traversal, fix the FileShredderService symlink data-destruction, fix the UndoRedoService redo-creates-folder bug. Small, isolated fixes, highest risk if left alone.

Mechanical lint-caught fixes — the 7 no_redundant_bool_comparison hits and the no_naive_path_prefix_check hits are trivial, low-risk, and now enumerated by swiftlint. Good next since they're nearly free.

The one "Change" architecture verdict — delete FileSystemServiceProtocol/ThumbnailServiceProtocol (unused, per the meta-architecture pass). Small, clear, no ambiguity.

DRY/Architecture refactors (ARCHITECTURE.md) — the Grid/List Strategy extraction, the shared AsyncResultView loading-state-machine, consolidating the 5 duplicate "unique name" implementations. Bigger effort, but each is self-contained and reduces future bug surface (this is where new bugs tend to get introduced by drift).

Product/UX polish (PRODUCT-UX.md) — hardcoded strings, accessibility gaps, Settings inconsistency. User-facing but not urgent; good filler work between the above.

Performance (PERFORMANCE.md) — mostly minor, except FolderPickerSheet's synchronous main-thread tree build (real stall) and PathBarView's triple-recompute. Worth doing but nothing here is a ticking clock.