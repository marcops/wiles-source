# Architecture & Code Review

> Cycle 2 — full review of `Sources/Wiles/` **including** the files listed in `TODO/eval/IGNORAR.md`.
> Findings deleted from this file as fixed; findings skipped due to genuine doubt remain.

## Findings by ID

_Nenhum finding novo de lista principal neste ciclo._

Cycle 2 cobriu (além da varredura de padrões de todos os 287 arquivos feita no Cycle 1):
- Os ~80 arquivos listados em `IGNORAR.md` — todos confirmados triviais como rotulado (enums de token,
  structs de dados, view modifiers de 1 linha, wrappers de comando de menu). Amostra verificada:
  `DebouncedWriteRegistry`, `ByteFormat`, `FailableDecodable`, `ImageFileType`, `SmartFolderStore`,
  `DefaultFolderHandlerService`, `AsyncResultView`, `KeyboardZoomController`, `SidebarSectionContainer`,
  `AsyncDelayTokens`, `URL+WellKnownLocations`, `MoveCollisionPolicy`, `ParsedSearchQuery`,
  `DirectoryLoadOptions`, `DirectoryLoadResult`, `FileOperationTask`, `HapticService`, `ApplicationApp`,
  `UndoActionType`, `BatchMoveOutcome`, `SearchQueryWarning`, `TrailingInspector`, `AppMenuCommands`,
  `HelpMenuCommands`, `GoMenuCommands`, `ToolsMenuCommands`, `LocalizedCommands` — sem lógica de risco.
- Serviços/models antes não lidos linha-a-linha: `DiskSpaceVisualizerService`, `ColumnAutoFitService`,
  `FinderStyleTruncationService`, `FilePermissionsService`, `SyntaxHighlighterService`, `OpenWithService`,
  `CopyPathService`, `SystemTagsService`, `NSImage+ResizedCopy` — todos endurecidos (referências
  R1/BA-509/BB-462/LL-025 nos comentários), bounded caches, enumerators com `errorHandler`,
  `Task.checkCancellation()` + `Task.yield()` em loops profundos, `directoryTraversable` para não
  trancar o usuário fora da própria árvore.
- Views de lifecycle relevante: `MainContentView` (teardown per-window + `willTerminate` para ⌘Q,
  `.task` uma vez por identidade, sem refresh no `init`), `InlineRenameField` (commit idempotente em
  focus-loss e Return, cancel via Esc não commita), `FileListView` (GeometryReader escopado a
  preference-key), `PathBarView` (breadcrumb cacheado em `@State`, scroll com debounce, `maxPathDepth`
  contra loop patológico, um único drop handler compartilhado).

## NOT WORTH

- [SL-000] LOW / UX — `FileShredderService` partial cancel: shred de N arquivos e cancelar pelo ✕ do popover apaga até o ponto do cancel e `runDetachedFileOperation`'s `catch is CancellationError` engole sem um resumo "M de N apagados permanentemente". Não é perda de dados (deleção pedida pelo usuário), só falta feedback; ROI < 1.
- [ML-000] LOW / UX — desfazer um paste-**copy** (`.createFile` por arquivo) não pode ser refeito (`redoable = false`); a origem ainda existe, um action type `.copy(source,dest)` permitiria o redo, mas o ROI de um novo action type é < 1.
- [MM-000] MEDIUM / PERFORMANCE — `LocalHttpServerService+FileStreaming` lê cada chunk de 64 KB (`fileHandle.read`) na serial `queue` dentro do completion do `connection.send`, então um download de uma pasta compartilhada em `/Volumes` lento faz head-of-line-block em toda conexão em voo; o path de directory-listing já foi movido para fora da `queue` (LM-069), o streaming não. ROI 0.56 (precisa de pasta compartilhada em mount lento + clientes concorrentes); sem gatilho de safety-gate.
- [SL-000] LOW / DRY — `DirectoryMonitor` (FSEvents) e `FolderWatcher` (DispatchSource) são dois mecanismos de folder-watch; semânticas genuinamente diferentes (recursivo/path vs. single-dir/fd), combinar adicionaria complexidade.
- [ML-000] LOW / EDGE — o branch temp-hop de case-only-rename em `performRenameOnDisk` também roda em volume case-**sensitive** onde um move direto funcionaria (e falha de forma confusa se um arquivo distinto já ocupa o nome com o novo case); inofensivo (faz rollback), só um path desnecessário.
- [SL-000] LOW / DRY — `AutoOrganizationSheet.ruleStatusText` cria um `DateFormatter()` por render; modal fora de hot-path, e o lint heurístico disso (`no_formatter_built_in_view`) foi removido de propósito por falso-positivo.
- [ML-000] LOW / EDGE — `NavigationStore.completeNavigation` chama `navigation.addToRecents(url)` com o `url` não-standardizado (linha antes de `standardizedURL` ser derivado). `addToRecents` re-standardiza internamente, então efetivamente inofensivo.
- [SL-000] LOW / PERFORMANCE — `FileTaggingService.currentTags` faz um `itemsSnapshot.first(where:)` O(n) por URL alvo dentro de um `Dictionary(...)` map → O(seleção × items); seleções são pequenas na prática.
- [SL-000] LOW / PERFORMANCE — `SystemTagsService.startObserving` observa `NSWorkspace.didActivateApplicationNotification` (`object: nil` — qualquer app), então cada alt-tab entre quaisquer dois apps re-parseia as prefs do Finder (`FavoriteTagNames`, array de 8). Só é necessário quando o Wiles fica ativo; `NSApplication.didBecomeActiveNotification` seria suficiente. Parse minúsculo, ROI < 1.

## Suggested New Engineering Rules

### SUGESTÃO DE NOVA REGRA — "Every temp/staging artifact under a user folder has a prefix + a sweep"
- Regra: qualquer código que estaciona um arquivo do usuário (ou um archive inteiro em staging) sob um nome oculto dentro de um diretório **visível ao usuário** (não `NSTemporaryDirectory()`) DEVE (a) usar uma constante de prefixo compartilhada documentada, e (b) ser coberto por um sweep de recuperação de crash-orphans no ponto de entrada. Novos prefixes entram no sweep na mesma mudança.
- Problema que evita: artefatos de staging órfãos pós-crash consumindo disco silenciosamente ou (pior) sendo apagados por um sweep *irmão* que não sabe que eles guardam dados vivos.
- Exemplos: `.wiles-rename-` / `.wiles-replace-` (`sweepStaleRenameTemps`), `.wiles-batch-rename-` (`recoverStrandedStagingTemps`), e agora `.wiles-unzip-` (`sweepStaleUnzipStagingDirs`, adicionado no round 7). Foi exatamente o padrão do CH-190 (sweep apagando dados vivos) e MM-078 (staging sem sweep) do ciclo anterior.
- Deveria virar: code-review rule.

### SUGESTÃO DE NOVA REGRA — "A subprocess wait in a service is cancellable or it's a bug"
- Regra: qualquer `Process` + `waitUntilExit()` em `Sources/` para `ditto`/`zip`/`tar`/`unzip`/`hdiutil` DEVE fazer poll de `Task.isCancelled` + `terminate()` (ou reusar `ArchiveService.runProcess` / `ArchiveService.waitForExitOrCancel`). Um `waitUntilExit()` nu nessas ferramentas é finding blocking em review. Além disso, o wrapper que roda o corpo deve ser `CancellableWork.detached`, não `Task.detached` nu, senão o `Task.isCancelled` interno nunca dispara.
- Exemplos: `ArchiveService.runProcess` — correto (referência). `ArchiveInspectionService` — corrigido no round 7.
- Deveria virar: SwiftLint custom rule (abaixo) + code-review rule.

## Suggested Lint Rules

### Lint candidate — `bare_process_wait_for_archive_tool`
- Regra proposta: sinalizar um `.waitUntilExit()` num arquivo que também constrói um `Process` cujo `executableURL`/`arguments` referenciam `/usr/bin/ditto`, `/usr/bin/zip`, `/usr/bin/tar`, `/usr/bin/unzip`, ou `/usr/bin/hdiutil`, a menos que o mesmo escopo contenha `Task.isCancelled`, `withTaskCancellationHandler`, ou `waitForExitOrCancel`.
- Detecção automática: sim — SwiftLint custom rule (precisa de "mesmo arquivo, duas condições, uma negativa"; regex de 1 linha não expressa a guarda negativa sem falso-positivo).
- Risco de falso-positivo: baixo mas não zero (um one-shot genuinamente rápido, tipo um version probe, dispararia). Dado o bar "100% assertivo / zero falso-positivo": só como `severity: warning` advisory que um `// swiftlint:disable:next` com razão limpa — **não** como `--strict` build-breaking. Ou fica só em checklist de review.

(Nenhuma nova regra regex zero-falso-positivo identificada neste ciclo.)

## Files That Could Be Added to IGNORAR.md

Nenhum arquivo novo sugerido neste ciclo. Os ~80 já listados foram re-verificados como triviais.
Candidatos marginais que NÃO recomendo adicionar (têm um mínimo de lógica que merece re-olhar num
refactor): `ImageFileType.swift` (delega a `FileKindCatalog` mas define a política "raster estreito"),
`SmartFolderStore.swift` (3 flags de sessão com invariantes documentados). Ficam de fora do `IGNORAR.md`.

## NOTA DO PROJETO

### Global — 9.3 / 10
Segundo ciclo consecutivo confirmando: codebase excepcionalmente maduro. Cycle 2 — que incluiu
deliberadamente os ~80 arquivos "triviais" do `IGNORAR.md` e todos os serviços/models/views ainda
não lidos linha-a-linha — encontrou **zero findings de lista principal**. Os arquivos do `IGNORAR.md`
são de fato triviais (o rótulo está correto). O resto do código carrega o mesmo padrão de rigor visto
no Cycle 1: enumerators com `errorHandler`, caches bounded (`NSCache` com count/cost limit),
cancelamento estrutural, `autoreleasepool` em loops de bitmap, teardown per-window explícito.

### Arquitetura — 9 / 10
Sem mudança de avaliação em relação ao Cycle 1. A arquitetura própria (facade `AppState` + domain
stores; per-window vs shared classificado explicitamente; Service+SheetView por feature;
`CancellableWork`/`runDetachedFileOperation` como política única) segue coerente. O único ponto de
API privada de dependência (reflection no SwiftTerm) foi endurecido no round 7 (bug de IUO corrigido
+ canary CI). As duas mecânicas de folder-watch coexistem por razão legítima.

### Código — 9.4 / 10
Nada novo a apontar. Os 3 findings do Cycle 1 (CH-190, MM-143, MM-078) foram corrigidos no round 7
com testes de regressão. Os itens em NOT WORTH deste ciclo são todos LOW e sem gatilho de safety-gate
(o único MEDIUM, `LocalHttpServerService+FileStreaming` head-of-line block, tem ROI 0.56 e depende de
pasta compartilhada em mount lento + clientes concorrentes).

### Produto / negócio — 8.6 / 10
Sem mudança. Feature set amplo com UX defensiva consistente (confirmações, notas de "sem undo",
sinais de truncamento, estados de erro/empty/loading explícitos). O `SystemTagsService` já lê a lista
real de tags do Finder em vez de um set hardcoded — bom para evolução.

### Testabilidade estrutural — 9.2 / 10
Lógica consistentemente extraída para funções puras testáveis, com seams de injeção (`WorkspaceOpening`,
`encode:`, `directories:`, `fileManager:`, `modifierFlags:`). O canary de reflection do SwiftTerm
(adicionado no round 7) fechou o último buraco identificado.

## FINDINGS skipped by comments in the SOURCE CODE

Nenhum finding foi descartado por causa de um comentário no código-fonte neste ciclo. Onde um
comentário documenta um trade-off aceito (ex.: `MainContentView.init` "não chama refresh aqui",
`ByteFormat`/`FinderStyleTruncationService` `nonisolated(unsafe)` + `NSLock`), o comportamento foi
verificado como correto — não foi caso de "ignorei porque tinha comentário".
