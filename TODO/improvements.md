
- regras de organização não deixa selecionar qualquer pasta apenas as principais (ex: download, documentos e etc) tem que deixar so a arvore direto, sem aquele favoritos , e a arvore inteira nao esta limitada que tem hje
- se eu quero mover 1 arquivo o PATH BAR tem que abrir, e eu posso entrar dai nos diretorios ir direto para 1 deles.


o gridview tem que mostrar 2 linhas igual o ifinder se o texto for muito grande, e se for maior que isto ai sim coloca os 3 ppontos


bug grave, parou de pegar eu digitando, tanto na busca quando no nova pasta, o que eu fiz a principio foi abrir a busca para digitar e fiz resize depois disso nao pegou mais eu digitando nada na busca, nao consigo gitira rmais na buscacon



# Wiles — Resolution Plan

Action checklist from the 2026-08-09 AGENTS.md-compliance audit. Ordered by priority. Each fix must
follow rule 28 (red-green test) and rule 38 (self-audit before commit) from `.agents/AGENTS.md`.

---

## P4 — Rule 3 / Rule 7 length violations (lower urgency, real debt)

Decompose into `@ViewBuilder` sub-properties / private helpers. Suggested order by size:
- [ ] `Views/Components/SharedFileItemContextMenu.swift` (240-line body; also move the unrelated
      `colorForTag(_:)` free function and `AppState` extension out of this file — rule 14/SRP)
- [ ] `Views/Content/MainContentView.swift` (142-line body, ~18 chained `.sheet`)
- [ ] `Views/Modals/FilePropertiesSheet.swift` (132-line body)
- [ ] `Views/Sidebar/SidebarView.swift` (125-line body)
- [ ] `Views/Sidebar/SidebarRowView.swift` (117-line body — do this alongside the context-menu
      extraction above, it'll shrink naturally)
- [ ] `Views/Content/FileGridView.swift` / `FileListView.swift` (~100-line bodies)
- [ ] `Features/DuplicateCleaner/DuplicateDetectionService.swift:findDuplicates(in:)` (47 lines)
- [ ] `Views/Components/FileItemInteractionsModifier.swift:body(content:)` (39 lines — this is
      shared infra, prioritize despite being "only" medium severity)
- [ ] `Views/Modals/AutoOrganizationSheet.swift:ruleRow(_:)` (43 lines, low)
- [ ] `Views/Content/FileColumnView.swift:selectItem(...)` (36 lines, low)

## P7 — Product decisions (need your call, not just a fix)

- [ ] **Wi-Fi folder sharing has no authentication.** `NetworkServerService.swift`,
      `LocalHttpServerService.swift`, `HttpShareSheet.swift` — zero password/credential/auth
      anywhere. Decide: add a passcode/PIN to the share sheet, or explicitly document it as
      "trusted network only" in the UI (a one-line warning in `HttpShareSheet`) so it's a known
      tradeoff, not a silent gap.
- [ ] **No CI.** Neither `wiles` nor `wiles-public` has `.github/workflows/`. `scripts/validate.sh`
      is comprehensive but 100% manual. Minimal fix: a GitHub Actions workflow that runs
      `validate.sh` on push to `main` — turns rule 38 (mandatory self-audit) into an actual gate
      instead of an honor system.
- [ ] **No crash/error observability.** Zero `os_log`/`Logger` usage anywhere, no crash reporting.
      Given the app is unsandboxed/unnotarized, a crash in the wild is invisible unless a user
      files a GitHub issue. Consider a minimal local crash log (signal/NSException handler writing
      to a file in Application Support) as a first step — no need for a third-party SDK given the
      100%-native-APIs rule.
