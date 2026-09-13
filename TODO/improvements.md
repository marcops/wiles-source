## Low priority / undecided
- hoje ele pula os testes no ci tem que arrumar
- permitir o usuário configurar seus proprios atalhos


- zip feature
Double-clicking a `.zip` file should open it in-place the same way a real folder does (reusing whichever view mode is active — Grid/List Column) and let the user navigate inside it normally. Double-clicking a file *inside* that zip should extract it to a temporary location and open it (like macOS does when peeking inside a `.app` bundle).
Once this lands, the existing "Inspect Archive" context-menu sheet (`ArchiveInspectionSheetView`) becomes redundant and should be removed — this feature absorbs it.


### Constants/CrashReportingConstants.swift
- **[SECURITY]** Line 15 hardcodes a live-looking GitHub Personal Access Token (`githubToken = "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"`) directly in committed Swift source. Even scoped to `Issues: Read and write` on one repo, a committed PAT is a credential leak the moment this repo is public or the token isn't rotated/revoked — move it out of source entirely (environment variable, Keychain, or a git-ignored local config file loaded at runtime) and **revoke/rotate the current token now since it has already been committed to history**.

colocar no build do validate, release (gh), push and relaunch (ordem por ganho vs dificuldade)

2. MemberImportVisibility       🚫 bloqueado — SwiftTerm (dependência) precisa de `import AppKit` em vários arquivos internos; código vendored, não dá pra corrigir sem fork
7. InternalImportsByDefault      🚫 bloqueado — GitBeacon corrigido e confirmado v0.0.4 (revalidado, zero erros de lá); único bloqueio restante é o SwiftTerm (mesma causa raiz do item 2)


## Search Filters menu is hidden
The "Search Filters" control (scope: file name / file content, `kind:` tokens) only appears
once the search field is open and is easy to overlook. A small always-visible affordance, or
surfacing the scope toggle next to the field, would help people find content search.