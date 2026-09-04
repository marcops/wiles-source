# LOOP.md — Spec do loop autônomo de code review do Wiles

> **Para rodar:** me diga "roda o TODO/loop.md" (ou "continua o loop"). Tudo que preciso está aqui —
> não preciso perguntar nada de novo; as decisões já tomadas estão em "Regras herdadas".

---

## 1. Missão

Executar `TODO/eval/eval.md` como uma revisão arquitetural + de código **linha a linha, COMPLETA**
de `Sources/Wiles/`, em ciclos, **indefinidamente, a cada 3h**.

## 2. Contexto fixo

- Repo git: **`/Users/marco/source/wiles`**. O pai `/Users/marco/source` **não** é repo — sempre
  `cd /Users/marco/source/wiles` antes de qualquer `git`/`scripts/*`.
- Branch **`main`**. Commits direto em `main`; push `origin/main`; `git pull --rebase origin main`
  antes de push.
- Ler antes de revisar/escrever: `.agents/DEV_RULES.md`, `.agents/SWIFT_LANG_RULES.md`,
  `.agents/WILES_RULES.md`, `.agents/WILES_UI_UX_RULES.md`, `.agents/GENERAL_RULES.md`.
- **Sem subagents.**
- **Não commitar este arquivo** (`TODO/loop.md`) nem outros `TODO/loop*.md`.
- Commits em inglês, Conventional Commits, trailer `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## 3. Estrutura dos ciclos

- Ciclo `N` (N = 1, 2, 3, …). "round" no commit = **N + 5** (ciclo 1 = round 7). Rounds 1–6 foram
  rodadas anteriores a esta sessão.
- **Ciclo ÍMPAR** → revisar `Sources/Wiles/` **PULANDO** os arquivos de `TODO/eval/IGNORAR.md`.
- **Ciclo PAR** → revisar **TUDO, INCLUINDO** os arquivos de `IGNORAR.md`.
- **Entre ciclos: esperar 3h.** No wake, comparar `date -u` com o timestamp do último commit
  "round N" (`git log -1 --format=%ci`). Se < 3h → reagendar wakeup (~3600s) e parar.
  (A exceção histórica — 3h só entre ciclo 1→2, e 2→3 direto — já foi cumprida. De 3 em diante: 3h sempre.)
- Relatório de cada ciclo = arquivo **NOVO** `TODO/ARCHITECTURE_CODE_REVIEW_<N>.md`.
  **NUNCA sobrescrever** um relatório numerado existente.

## 4. Procedimento de um ciclo (regras ATUAIS)

1. `git pull --rebase origin main`. `git log --oneline <commit do último ciclo>..HEAD` — se entrou
   código de outro trabalho, focar a revisão nesses diffs primeiro.
2. Rodar o `eval.md` como revisão completa linha a linha (escopo conforme ímpar/par).
3. Escrever `TODO/ARCHITECTURE_CODE_REVIEW_<N>.md` com todas as seções do `eval.md`:
   Findings by ID · NOT WORTH · Suggested New Engineering Rules · Suggested Lint Rules ·
   Files That Could Be Added to IGNORAR.md · NOTA DO PROJETO ·
   FINDINGS skipped by comments in the SOURCE CODE.
4. Postar % de progresso + contagem H/M/L no chat conforme avança.
5. **NÃO CORRIGIR NADA AUTOMATICAMENTE.** Se achar um finding novo: documentar completo no
   relatório **e apresentar completo no chat**, e **PARAR** nesse finding — sem teste, sem código,
   sem commit de fix. Esperar o usuário validar antes de **qualquer** mudança que altere comportamento.
6. **Não encostar** nos itens de NOT WORTH — o usuário revisa 1 por 1.
7. Sanity check (o loop não altera código): `swift build -c debug` + `swiftlint --strict` +
   `swiftformat --lint .`.
8. `git add TODO/ARCHITECTURE_CODE_REVIEW_<N>.md` (e nada mais, a menos que o usuário já tenha
   aprovado um fix). Commit: `docs: architecture & code review cycle <N> (round <N+5>)` + body
   resumindo + trailer. `git pull --rebase origin main`; `git push origin main`.
9. Anexar linha ao **LOOP PROGRESS LOG** (fim deste arquivo):
   `Cycle <N> (ímpar/par): DONE <data>. Commit <hash> round <N+5>. Findings: <n> (aguardando validação / nenhum).`
10. Agendar próximo wakeup (~3600s; re-checar o gate de 3h a cada wake) para o Ciclo `<N+1>`.

## 5. Regras herdadas (perguntas já respondidas — NÃO perguntar de novo)

- **Se um dia voltar a corrigir**: SÓ testes unitários de **LÓGICA**. Nada de UI test, nada de
  `UI_TEST_BACKLOG.md`, nada relativo a UI. Padrão: plain `XCTestCase` como em
  `Tests/WilesTests/FileSystem/`. Para fixar: criar teste → codificar → `swift build -c debug`.
  Dúvida genuína num finding → pular, deixar no arquivo.
- **Fim de ciclo com código alterado** (só se o usuário aprovar um fix): `scripts/validate.sh` →
  corrigir tudo (lint/format/build) → 1 commit → `git push origin main`.
- **WilesUITests** falha em ambiente headless com "Timed out while enabling automation mode" — isso
  é **ambiental, não é defeito de código**. `swift build` (ambos toolchains) + `swift test` +
  SwiftLint `--strict` + SwiftFormat verdes = pass.
- **Loop quando limpo**: continuar igual — relatório + commit report-only todo ciclo,
  indefinidamente, mesmo sem findings.
- **Não decidir parâmetros técnicos** (plataforma / versão / escopo) sozinho — perguntar.
- **"Não faça nada que altere comportamento sem validar antes."** Regra geral. Bug fix altera
  comportamento → precisa de validação.
- MM-143 (mudança de runtime do round 7 — o SIGKILL do shell no ⌘Q agora funciona de verdade) foi
  **aprovado explicitamente** pelo usuário. Manter.

## 6. Histórico (round = cycle + 5)

- **Round 7 = Cycle 1** (ímpar): commit `02b330d`. 3 findings corrigidos:
  - **CH-190** (CRITICAL): `moveItemReplacingSync` deixava o arquivo deslocado sob
    `.wiles-replace-<UUID>` na pasta destino quando `trashItem` falha (share SMB/AFP, drive FAT);
    `sweepStaleRenameTemps` apagava depois de 60s → **perda de dados** + Undo `.trash` falhava.
    Fix: `recoverUntrashableDisplacedFile` renomeia para `<nome> (replaced).<ext>` visível e
    não-varrido. Testes: `Tests/WilesTests/FileSystem/FileSystemReplaceRecoveryTests.swift`.
  - **MM-143** (MEDIUM): `TerminalViewCache.reflectShellPid` nunca resolvia — `process` é
    `LocalProcess!` (IUO), o segundo `Mirror` andava no wrapper `Optional`. Logo o SIGKILL do shell
    no ⌘Q (MM-122) estava **inerte**. Fix: desembrulha 1 camada de optional + canary CI
    (`Tests/WilesTests/Views/TerminalShellPidReflectionCanaryTests.swift`). Runtime change aprovado.
  - **MM-078** (MEDIUM): extração de 1 entry do Archive Inspector com `waitUntilExit()` sem
    cancelamento + staging `.<UUID>_unzip` sem sweep de crash. Fix: `ArchiveService.waitForExitOrCancel`
    (poll/terminate/throw), rota por `CancellableWork.detached`, `ArchiveInspectionSheetView` cancela
    a Task no dismiss, `ArchiveInspectionService.sweepStaleUnzipStagingDirs` (prefixo `.wiles-unzip-`).
    Testes: `Tests/WilesTests/FileSystem/ArchiveInspectionCancellationTests.swift`. Também:
    `Package.swift` ganhou `SwiftTerm` como dep de teste.
- **Round 8 = Cycle 2** (par, incluiu IGNORAR): commit `6b0c3b1`. **0 findings novos.** Relatórios
  passaram a ser numerados por ciclo: `ARCHITECTURE_CODE_REVIEW.md` → `_1.md`; novo `_2.md`.
  `validate.sh` = "All checks passed" (build ×2, 250 testes, WilesUITests, SwiftLint, SwiftFormat).
- **Round 9 = Cycle 3** (ímpar): commit `b840b2a` (2026-09-03 03:34 UTC). **0 findings novos.**
  Relatório `ARCHITECTURE_CODE_REVIEW_3.md`.
- **Round 10 = Cycle 4** (par, incluiu IGNORAR): commit `5e75b0d` (2026-09-03 19:58 UTC).
  **0 findings novos.** Relatório `ARCHITECTURE_CODE_REVIEW_4.md`. `swift build -c debug` +
  `swiftlint --strict` (0) + `swiftformat --lint` (0) = verde.
- **PRÓXIMO: Cycle 5** (ímpar → pula IGNORAR, round 11) quando passar 3h de `5e75b0d`
  (gate ≈ 2026-09-03 22:58 UTC).

## 7. NOT WORTH pendentes (usuário revisa 1 por 1 — NÃO corrigir sem ordem)

- **MEDIUM / PERF** — `LocalHttpServerService+FileStreaming` lê cada chunk de 64KB (`fileHandle.read`)
  na serial `queue` dentro do completion do `connection.send` → um download de pasta compartilhada
  num `/Volumes` lento faz head-of-line block em toda conexão em voo. O directory-listing já foi
  movido pra fora da `queue` (LM-069); o streaming não. ROI 0.56, sem gatilho de safety-gate.
- **LOW / PERF** — `SystemTagsService.startObserving` observa `NSWorkspace.didActivateApplicationNotification`
  (`object: nil` — qualquer app) → re-parseia as prefs do Finder a cada alt-tab entre quaisquer 2
  apps. Bastaria `NSApplication.didBecomeActiveNotification`. Parse minúsculo (array de 8).
- **LOW / UX** — `FileShredderService` cancel parcial: apaga até o ponto do cancel e
  `runDetachedFileOperation`'s `catch is CancellationError` engole sem resumo "M de N apagados".
- **LOW / DRY** — `DirectoryMonitor` (FSEvents) vs `FolderWatcher` (DispatchSource): dois mecanismos
  de folder-watch, semânticas genuinamente diferentes; combinar adicionaria complexidade.
- **LOW / EDGE** — branch temp-hop de case-only-rename em `performRenameOnDisk` roda também em
  volume case-sensitive onde um move direto funcionaria (inofensivo, faz rollback).
- **LOW / DRY** — `AutoOrganizationSheet.ruleStatusText` cria um `DateFormatter()` por render
  (modal fora de hot-path; o lint heurístico disso foi removido de propósito).
- **LOW / EDGE** — `NavigationStore.completeNavigation` chama `addToRecents(url)` não-standardizado
  (`addToRecents` re-standardiza internamente — efetivamente inofensivo).
- **LOW / PERF** — `FileTaggingService.currentTags` faz `itemsSnapshot.first(where:)` O(n) por URL
  alvo → O(seleção × items); seleções são pequenas na prática.

## 8. Regras de engenharia sugeridas (recorrentes nos relatórios)

- **"Todo artefato temp/staging sob uma pasta do usuário tem prefixo + sweep"** — prefixo constante
  documentado + sweep de crash-orphans no ponto de entrada. Exemplos: `.wiles-rename-` /
  `.wiles-replace-` / `.wiles-batch-rename-` / `.wiles-unzip-`.
- **"Espera de subprocess num service é cancelável ou é bug"** — `Process` + `waitUntilExit()` para
  `ditto`/`zip`/`tar`/`unzip`/`hdiutil` DEVE fazer poll de `Task.isCancelled` + `terminate()`
  (ou reusar `ArchiveService.runProcess` / `waitForExitOrCancel`), E o wrapper deve ser
  `CancellableWork.detached`, não `Task.detached` nu.
- **Lint candidate** `bare_process_wait_for_archive_tool` — só como `warning` advisory
  (não `--strict`), risco de falso-positivo não é zero.

---

## LOOP PROGRESS LOG
(append aqui a cada ciclo)

- Cycle 1 (ímpar — pulou IGNORAR): DONE 2026-09-03. Round 7 = `02b330d`. Findings: 3 corrigidos (CH-190, MM-143, MM-078).
- Cycle 2 (par — incl. IGNORAR): DONE 2026-09-03. Round 8 = `6b0c3b1`. Findings: 0.
- Cycle 3 (ímpar — pulou IGNORAR): DONE 2026-09-03. Round 9 = `b840b2a`. Findings: 0.
- Cycle 4 (par — incl. IGNORAR): DONE 2026-09-03. Round 10 = `5e75b0d`. Findings: 0.
