# Architecture & Code Review

> Cycle 3 — review of `Sources/Wiles/` **skipping** the files listed in `TODO/eval/IGNORAR.md` (odd cycle).
> Focus: non-IGNORAR files not yet read line-by-line in cycles 1–2 (app lifecycle, Views, Settings,
> Sidebar, Modals, keyboard navigation, remaining Services/Models).
> Findings deleted from this file as fixed; findings skipped due to genuine doubt remain.

## Findings by ID

_Nenhum finding novo de lista principal neste ciclo._

Cobertura desta passagem (não-IGNORAR, não lidos linha-a-linha nos ciclos 1–2):
- **App lifecycle**: `WilesApp` (setup pesado adiado para `.task` uma vez por processo, guardado por
  `didRunLaunchSetup`; `AutoOrganizationService.shared.startMonitoring()` chamado uma vez no nível de
  app — confirma que a preocupação do Cycle 1 sobre lifecycle de singleton com `.onAppear` NÃO se
  aplica aqui), `WilesAppDelegate` (`flushAll` + `TerminalProcessRegistry.tearDownAll` em
  `applicationWillTerminate` para ⌘Q — MM-171/MM-122), `SystemAppearanceObserver` (token de
  `DistributedNotificationCenter` armazenado, singleton app-lifetime, init roda uma vez — regra #21 OK).
- **Keyboard nav**: `KeyboardSelectionNavigator` (stateless, extraído do NSView para testabilidade;
  anchor via `keyboardSelectionAnchorURL` nunca `.first` de um `Set`; range shift-select correto),
  `FileMenuCommands` (itens destrutivos `.disabled` quando o terminal está focado — CH-321).
- **Modals de risco**: `FilePropertiesSheet` (chmod com `.chmod` undo no path não-recursivo;
  recursivo é confirmation-gated + sem undo por design R4; task cancelada no `.onDisappear` — LL-025;
  leituras em paralelo com `async let`), `FolderPickerSheet` (walk de ancestrais off-`@MainActor`
  para `/Volumes`, `isDescendantOrSelf` em vez de prefixo de string, mirrors dos patterns de
  navegação).
- **Sidebar / componentes**: `SidebarRowView` (`.task(id:)` cancellation-aware para checks de
  ejectable/missing-favorite off-`@MainActor`; builders de chave puros e testáveis; sinal FSEvents
  de alta frequência dobrado só no favorito relevante — regra High-Frequency Interaction State),
  `RootDirectoryTreeLoader` (timer GCD em vez de `Task.sleep` para não starvar o pool cooperativo;
  seams injetáveis — LL-020), `BoundedFolderNodeCache` (capado, eviction por ordem de inserção,
  chaves standardizadas).

## NOT WORTH

- [SL-000] LOW / UX — `FileShredderService` partial cancel: shred de N arquivos e cancelar pelo ✕ apaga até o ponto do cancel e o `catch is CancellationError` engole sem resumo "M de N apagados". Não é perda de dados (deleção pedida), só falta feedback; ROI < 1.
- [ML-000] LOW / UX — desfazer um paste-**copy** não pode ser refeito (`.createFile` com `redoable = false`); a origem ainda existe, mas o ROI de um novo action type `.copy` é < 1.
- [MM-000] MEDIUM / PERFORMANCE — `LocalHttpServerService+FileStreaming` lê cada chunk de 64 KB na serial `queue` dentro do completion do `connection.send` → head-of-line block em toda conexão em voo quando a pasta compartilhada está num `/Volumes` lento; o directory-listing já foi movido (LM-069), o streaming não. ROI 0.56, sem gatilho de safety-gate.
- [SL-000] LOW / DRY — `DirectoryMonitor` (FSEvents) e `FolderWatcher` (DispatchSource): dois mecanismos de folder-watch com semânticas diferentes; combinar adicionaria complexidade.
- [ML-000] LOW / EDGE — branch temp-hop de case-only-rename em `performRenameOnDisk` também roda em volume case-sensitive onde um move direto funcionaria; inofensivo (rollback).
- [SL-000] LOW / DRY — `AutoOrganizationSheet.ruleStatusText` cria um `DateFormatter()` por render; modal fora de hot-path; o lint heurístico disso foi removido de propósito.
- [ML-000] LOW / EDGE — `NavigationStore.completeNavigation` chama `addToRecents(url)` com `url` não-standardizado; `addToRecents` re-standardiza, efetivamente inofensivo.
- [SL-000] LOW / PERFORMANCE — `FileTaggingService.currentTags` faz `itemsSnapshot.first(where:)` O(n) por URL alvo → O(seleção × items); seleções pequenas na prática.
- [SL-000] LOW / PERFORMANCE — `SystemTagsService.startObserving` observa `NSWorkspace.didActivateApplicationNotification` (qualquer app) → re-parseia prefs do Finder a cada alt-tab entre quaisquer dois apps; só é necessário quando o Wiles fica ativo (`NSApplication.didBecomeActiveNotification`). Parse minúsculo, ROI < 1.

## Suggested New Engineering Rules

### SUGESTÃO DE NOVA REGRA — "Every temp/staging artifact under a user folder has a prefix + a sweep"
- Regra: qualquer código que estaciona um arquivo do usuário (ou um archive em staging) sob nome oculto dentro de um diretório **visível ao usuário** (não `NSTemporaryDirectory()`) DEVE usar uma constante de prefixo compartilhada documentada E ser coberto por um sweep de crash-orphans no ponto de entrada. Novos prefixes entram no sweep na mesma mudança.
- Exemplos: `.wiles-rename-` / `.wiles-replace-` (`sweepStaleRenameTemps`), `.wiles-batch-rename-` (`recoverStrandedStagingTemps`), `.wiles-unzip-` (`sweepStaleUnzipStagingDirs`, round 7). Foi o padrão de CH-190 (sweep apagando dados vivos) e MM-078 (staging sem sweep).
- Deveria virar: code-review rule.

### SUGESTÃO DE NOVA REGRA — "A subprocess wait in a service is cancellable or it's a bug"
- Regra: `Process` + `waitUntilExit()` para `ditto`/`zip`/`tar`/`unzip`/`hdiutil` DEVE fazer poll de `Task.isCancelled` + `terminate()` (ou reusar `ArchiveService.runProcess` / `waitForExitOrCancel`), E o wrapper deve ser `CancellableWork.detached` e não `Task.detached` nu (senão `Task.isCancelled` nunca dispara). Blocking em review.
- Exemplos: `ArchiveService.runProcess` (referência); `ArchiveInspectionService` corrigido no round 7.
- Deveria virar: SwiftLint custom rule (abaixo) + code-review rule.

## Suggested Lint Rules

### Lint candidate — `bare_process_wait_for_archive_tool`
- Regra proposta: sinalizar `.waitUntilExit()` num arquivo que também constrói um `Process` referenciando `/usr/bin/{ditto,zip,tar,unzip,hdiutil}`, a menos que o mesmo escopo tenha `Task.isCancelled` / `withTaskCancellationHandler` / `waitForExitOrCancel`.
- Detecção: SwiftLint custom rule (precisa de "mesmo arquivo, condição negativa").
- Falso-positivo: baixo mas não zero (version probe rápido dispararia). Dado o bar zero-falso-positivo: só `severity: warning` advisory com `// swiftlint:disable:next` + razão, **não** `--strict`. Ou fica em checklist de review.

(Nenhuma regra regex nova zero-falso-positivo identificada neste ciclo.)

## Files That Could Be Added to IGNORAR.md

Nenhum novo. Cycle 2 já re-verificou os ~80 listados como triviais. `KeyboardSelectionNavigator`,
`RootDirectoryTreeLoader`, `BoundedFolderNodeCache` carregam lógica com invariantes e NÃO devem ir
para o `IGNORAR.md`.

## NOTA DO PROJETO

### Global — 9.3 / 10
Terceiro ciclo consecutivo sem findings de lista principal. Cycle 3 cobriu o app lifecycle, a
navegação por teclado, os modais de risco (chmod), a sidebar e o folder picker — todos endurecidos
com os mesmos padrões (cancellation via `.task(id:)` / `.onDisappear`, off-`@MainActor` para
`/Volumes`, funções puras extraídas para testes, `isDescendantOrSelf` em vez de prefixo de string).

### Arquitetura — 9 / 10
Sem mudança. Confirmado no Cycle 3 que `AutoOrganizationService.shared` é iniciado uma única vez no
nível de app (`WilesApp.performLaunchSetupOnce`), não por `.onAppear` de view per-window — cumpre a
regra "Singleton Services With Session State Need an Explicit Owner". O `WilesAppDelegate` centraliza
os hooks de terminate-time (flush de debounce, SIGKILL dos shells do terminal).

### Código — 9.4 / 10
Sem mudança. Os 3 findings do ciclo 1 (CH-190, MM-143, MM-078) permanecem corrigidos (round 7). O
único MEDIUM em NOT WORTH (`LocalHttpServerService+FileStreaming` head-of-line block) tem ROI 0.56 e
gatilho estreito (pasta compartilhada em mount lento + clientes concorrentes).

### Produto / negócio — 8.6 / 10
Sem mudança. UX defensiva consistente: confirmações em ações destrutivas (chmod recursivo, empty
trash, delete permanente), notas de "sem undo", sinais de truncamento, Retry em timeout de build de
árvore, dimming de favoritos mortos.

### Testabilidade estrutural — 9.3 / 10
`KeyboardSelectionNavigator`, `RootDirectoryTreeLoader`, `SidebarRowView.favoriteStatusKey` /
`isFavoriteMissing`, `FolderPickerSheet.computeAncestorExpansion` / `isWithinOrEqual` — todos puros
e testáveis sem NSView/window, com seams injetáveis (`scan:`, `timeout:`).

## FINDINGS skipped by comments in the SOURCE CODE

Nenhum. Onde um comentário documenta um trade-off aceito (chmod recursivo sem undo — R4;
`SystemAppearanceObserver` token nunca removido — singleton app-lifetime; `RootDirectoryTreeLoader`
timer GCD em vez de `Task.sleep`), o comportamento foi verificado como correto.
