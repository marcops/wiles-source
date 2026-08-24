colocar no build do validate, release (gh), push and relaunch (ordem por ganho vs dificuldade)

1. ImmutableWeakCaptures        ✅ feito (validate.sh, push_and_relaunch.sh, release.yml)
2. MemberImportVisibility       🚫 bloqueado — SwiftTerm (dependência) precisa de `import AppKit` em vários arquivos internos; código vendored, não dá pra corrigir sem fork
3. InferIsolatedConformances    ✅ feito (validate.sh, push_and_relaunch.sh, release.yml)
4. NonisolatedNonsendingByDefault  ✅ feito (validate.sh, push_and_relaunch.sh, release.yml)
5. StrictMemorySafety           ✅ feito (validate.sh, push_and_relaunch.sh, release.yml)
6. ExistentialAny                ✅ feito (validate.sh, push_and_relaunch.sh, release.yml) — 17 usos corrigidos com `any`
7. InternalImportsByDefault      🚫 bloqueado — GitBeacon corrigido e confirmado v0.0.4 (revalidado, zero erros de lá); único bloqueio restante é o SwiftTerm (mesma causa raiz do item 2)

adicionar no build
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