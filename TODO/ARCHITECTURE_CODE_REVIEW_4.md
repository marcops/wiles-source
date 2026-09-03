# Architecture & Code Review

> Cycle 4 — full review of `Sources/Wiles/` **including** the files listed in `TODO/eval/IGNORAR.md`
> (even cycle). Line-by-line pass of every non-view logic file (Models, AppState + stores +
> preferences, Services, Features services/models) plus an anti-pattern sweep of the View layer.
> Findings deleted from this file as fixed; findings skipped due to genuine doubt remain.

## Findings by ID

_Nenhum finding novo de lista principal neste ciclo._

Cobertura desta passagem (round 10):

- **App lifecycle / menus** — `WilesApp` (heavy launch work guarded by `didRunLaunchSetup`, once
  per process; crash handler installed synchronously in `init` by design), `WilesAppDelegate`
  (`flushAll` + `TerminalProcessRegistry.tearDownAll` on `applicationWillTerminate` — MM-171 /
  MM-122; `didLaunchApplicationNotification` token stored — regra #21), all `*MenuCommands` (thin
  `@FocusedValue` wrappers; destructive items `.disabled` while terminal focused — CH-321).
- **Constants (IGNORAR)** — re-verified trivial: `AppConstants`, `AsyncDelayTokens`, `ByteFormat`
  (lock-guarded shared `ByteCountFormatter`), `CrashReportingConstants` (hardcoded PAT — B1-1,
  accepted), `DefaultsKey`, `HTTPStatus`, `IconSizeToken`, `KeyCode`, `LayoutTokens` (memoized
  two-line-label height, `nonisolated(unsafe)` + `NSLock`), `ShortcutRegistry` (single source of
  truth, completeness assertion in tests), `URL+Containment` (`isDescendantOrSelf` — one shared
  policy), `URL+WellKnownLocations`.
- **Models** — `AutoOrganizationRule` (custom `init(from:)` normalizes decoded URLs;
  `decodeIfPresent` for fields added later), `BoundedFolderNodeCache` (capped, insertion-order
  eviction, standardized keys), `ClipboardState` (O(1) `isCut` via `Set`), `DirectoryCacheEntry`
  (30s TTL), `DirectoryMonitor` (`passRetained` + `releaseContextInfo` — ML-120; type-scope
  `nonisolated` FSEvents callback; `NSLock`-guarded state), `FileItem` (`@unchecked Sendable` with
  post-init immutability; hash uses a valid subset of `==`; `@MainActor` date-formatter cache),
  `FileKindCatalog` (one catalog per concept), `FolderNode` (+ `+DirectoryTree`) (shallow `==` for
  perf; `ancestorRealPaths` loop guard; `errorHandler` on the has-subfolder probe — BA-509),
  `NSImage+ResizedCopy` (never mutates the shared system icon), `RuleConditionType` /
  `NavigationMode` (legacy raw-value acceptance), `WilesError` (token substitution, one source of
  truth per error), `MoveCollisionChoice` / `MoveCollisionPrompt` (idempotent `resolve`).
- **AppState + extensions** — `AppState` (`@MainActor` → implicitly `Sendable`; per-window services
  explicitly classified vs shared — BA-108 / R2), `AppState+Navigation` (`RefreshSnapshot`
  captured before the async hop; `isStillCurrent` staleness guard; `/Volumes` off-`@MainActor`
  probe with cancellation; cache fast-path only when query empty), `AppState+Move` (single
  `moveItem` entry point → `remapRelocatedState`; sequential collision loop with sticky choice;
  grouped undo — HH-089 / HM-146; `ML-048` re-throw when no window to prompt), `AppState+Operations`
  (`runDetachedFileOperation` structural off-main + `detached:` escape hatch for `@MainActor`
  operations — R3; `progressReportStride` actor-hop coalescing; `catch is CancellationError`
  swallow — MM-104), `AppState+ColumnsAndActions` / `+Favorites` (`isSameLocation` symlink-resolved,
  one policy; `remapFavorites` prefix check with the trailing `/`) / `+SmartFolders` / `+Trash` /
  `+Text` / `+Error` / `+Selection` (anchor never `Set.first`) / `+Archive` / `+SidebarVisibility`.
- **Stores** — `FileSystemStore` (streaming-batch depth *counter* not flag; monitor-refresh
  debounce with trailing edge to avoid the FSEvents self-sustaining loop; per-window `tearDown`),
  `NavigationStore` (optimistic `/Volumes` accept + off-main `validateRecentAndCurrentPaths`;
  `addToRecents` merges against `UserDefaults` not the in-memory copy; capped history/recents),
  `SelectionStore` (`cachedGridColumnCount` / `cachedSelectedFileSizeBytes` invalidated on change,
  read off the render path; silent search-query setter), `SlowVolumePathValidator` (mount-root vs
  target distinction — MH-118), `SmartFolderStore` / `TransientStore` / `ModalStore` (trivial),
  `TrashState` (token-guarded enumeration; `unreadableDirectories` counted as failures — LP-012;
  `cancelInFlight` for teardown; external-volume `.Trashes/<uid>` covered).
- **Preferences** — `PersistablePreferenceStore` (`isRestoringDefaults` seam; `loadBool`/`loadInt`
  distinguish "never saved" from an explicit `0`/`false`; `keysToEvict` evicts baseline before the
  just-added batch), `ViewPreferences` / `SidebarPreferences` (debounced writes via
  `DebouncedDefaultsWrite`, auto-registered for the terminate flush — MM-171 / ML-259; capped
  `expandedTreePaths` / `perFolderViewModes`; legacy-bool → enum migration for `trailingInspector`),
  `AppearancePreferences` / `SearchPreferences`, `FavoritesStore` (optimistic `/Volumes` +
  `validateSlowVolumeFavorites`; recomputed `standardized`/`resolved` path sets),
  `PreferencesStore(+SmartFolders)` (persist-to-disk-first, surface the error).
- **Services** — `FileSystemService` (+`+Actions`) (`directoryListingLimit` + `resultsTruncated`
  signal — R5; `moveItem` self-path guard before any FS touch; `moveItemReplacingSync` staged
  never destroy-then-move — HM-110; `recoverUntrashableDisplacedFile` — CH-190; `resolveTrashedItemURL`
  — MM-150; `sweepStaleRenameTemps` for `.wiles-rename-` / `.wiles-replace-` — MM-121;
  `Task.checkCancellation()` before caching a partial listing — LM-081), `SearchFilterService`
  (`ContentReadBudget` — MM-096; `invalidFilterTokenValue` — ML-140; bounded `contentCache`;
  encoding fallback chain), `ArchiveService` (`entryEscapesDestination` — HH-234;
  `runProcess` polls `Task.isCancelled` + `terminate()`; `BoundedStderr` / capped stdout;
  `waitForExitOrCancel`; `zipPasswordEnvironment` via env not argv; half-written archive removed on
  failure), `CancellableWork` (the one detached+forward-cancellation policy — AM-140 / HM-235),
  `UndoRedoService` (`isProcessing` guard; `recordActions` grouped — HH-089; failed step re-pushed
  not promoted to a bogus redo; `.createFile` redo is a silent no-op — ML-135; `noteRestoreDivergence`
  — MM-091), `PasteboardService` (bounded clipboard read; image-then-text order), `PDFMergeService`
  (off-`@MainActor`; `autoreleasepool` per image; zero-page guard), `UniqueFileNaming` (one Finder-
  convention utility), `FilenameSanitizer` (byte-count truncation keeping the extension — LL-010),
  `AutoOrganizationService` (off-main initial scan; 2s stability window + `crossVolumeExtraStableWindows`
  — LL-063; rule re-check after the window — LL-063b; `isSelfReferential` drop; ambiguous-match report),
  `AutoOrganizationRuleStore` (`FailableDecodable` per-record — ML-104; `isBumpingStats` + debounced
  stats persist), `BackgroundOperationsService` (per-window; cancellation handlers off the
  `Sendable` display model), `DebouncedDefaultsWrite` / `DebouncedWriteRegistry` (weak-held,
  `flush()` = perform-then-cancel), `DirectoryCacheService` (`NSCache` count + real cost limit;
  `maxCacheableItemCount`), `FileTaggingService` (re-reads tags from disk before writing — MM-219;
  `uniquingKeysWith` — ML-085), `SystemTagsService` (cache never read from `body` — ML-070),
  `ThumbnailService` (`InFlightThumbnail` awaiter refcount → cancel QL work when the last viewer
  scrolls away — MM-118; `ReleaseGuard` one-shot latch; per-path+mtime key, no shared mtime index —
  ML-090; cost-based cache limit), `ThumbnailPrefetcher` (per-window session — ML-102),
  `SymlinkService` (never delete-to-make-room; self-target guard), `FilePermissionsService`
  (one `attributesOfItem` read for owner/group/perms; recursive `errorHandler` + `Task.yield()` —
  BB-462 / LL-025; `directoryTraversable`), `POSIXPermissions` (special bits carried through),
  `FolderWatcher` (off-main `open(O_EVTONLY)` + generation guard — ML-103; cancel-handler closes fd,
  no double-close), `NetworkDiscoveryService` (`ifCurrent` blink guard; `isStopped` gate; per-resolver
  timeout task cancelled), `NetworkServerService` (space-in-share-name fallback — LU-020),
  `OpenWithService` (per-extension memo cap; `.effectiveIconKey` not IPC; invalidate on app launch),
  `CopyPathService` (`posixSingleQuoted`), `ColumnAutoFitService` (bounded measurement sample),
  `ExifMetadataService` / `FileMetadataService` (off-main; `AsyncStream` `onTermination` → cancel),
  `FileMetadataTooltipService` (mtime in the cache key — SL-090; off-main PDF/image header reads),
  `FinderStyleTruncationService` (reusable `TextKit` graph under `layoutLock`; quantised width;
  bounded caches), `SyntaxHighlighterService` (compiled-once regexes; comments before strings),
  `SystemAppearanceObserver` (app-lifetime singleton token, intentionally never removed),
  `PermissionService` (readability probe not enumeration), `AppLanguage`, `HTMLEscaping`,
  `L10n+Lookup` (locale-family fallback; `value: ""` → degrade to English not the raw key — ML-138;
  locked bundle cache), `Bundle+WilesResources` (real packaging layout before `Bundle.module`'s
  `fatalError`-on-miss accessor).
- **Features** — `LocalHttpServerService` (+ `+Networking` / `+DirectoryListing` / `+FileStreaming`)
  (`start` tears down the previous listener — BB-358; off-main port scan + `startGeneration` guard
  — ML-086; `stop()` flips observable state immediately then `queue.async` teardown; constant-time
  SHA-256 password compare; path-traversal boundary via `resolvingSymlinksInPath` + separator;
  `%00` / `//` reject; hidden entries refused both in listing and `serveFile`; `httpHead` list-based
  builder — LL-055; capped listing entries + truncation note; chunked streaming, `Content-Length`
  honesty on a mid-stream read failure), `ArchiveInspectionService` (`entryEscapesDestination` +
  post-resolve containment check — HH-234; `.wiles-unzip-` prefix + sweep — MM-078;
  `CancellableWork.detached` + `waitForExitOrCancel`; `uniqueDestination` never clobbers),
  `ZIPCentralDirectoryReader` (`Int(exactly:)` on attacker-controlled offsets — MM-247; ZIP64
  locator; CP437/Latin-1 name decode fallback; `maxEntryCount`), `BatchRenameService`
  (`assertNoCollisions` preflight; `stagePermutationCycles` through hidden temps — Preflight/Executor
  rule; `recoverStrandedStagingTemps` renames never deletes — MM-113; `restoreStaged` on early exit),
  `DuplicateDetectionService` (size → partial-hash → **full SHA-256** before any destructive step;
  a mid-file read error aborts the hash, never treated as EOF; `errorHandler` on the walk; capped
  scan + `wasTruncated`), `FileShredderService` (continues past per-item failures, aggregates;
  no fake "secure" overwrite — documented for APFS/SSD), `DiskSpaceVisualizerService` (detached +
  `withTaskCancellationHandler`; `errorHandler` + `maxScannedFileCount` + `isApproximate`),
  `SmartFolderService` (per-`AppState`, not `.shared` — BA-108; `currentQueryToken` +
  `fetchTask` cancellation; `NSPredicate(format:)` with `%@` substitution — regra #20;
  `spotlightContainsPattern` strips `*`/`"`; `maxResultCount` cap; save propagates the encode error),
  `SpotlightQuery` (resume-once `complete`; observer + timeout torn down together; `startsQuery`
  test seam), `ImageConverterService` (source-pixel guard from metadata *before* decode — ML-078;
  output-pixel guard; `autoreleasepool`; renders in the source color space; doc note "callers must
  run inside `Task.detached`" — R3).
- **Views (anti-pattern sweep)** — zero `AnyView`, zero `try!`/`as!`, zero `fatalError`/
  `preconditionFailure`/`print` in production, zero `DispatchQueue.*.sync`, zero `.shared`-service
  `start`/`stop`/`cancel` driven from a per-window view lifecycle. The only synchronous `FileManager`
  calls in `Views/` (`EmptyDirectoryView.isCurrentFolderReadable`, `SymlinkSheetView.createSymlink`)
  both short-circuit `/Volumes` paths off `@MainActor` and only touch a local path synchronously
  (microseconds — allowed by SWIFT_LANG_RULES.md). All heavy work in `Views/` goes through
  `Task.detached` / `CancellableWork` with a cancellation path (`SidebarRowView.task(id:)`,
  `FilePropertiesSheet.onDisappear` — LL-025, `RootDirectoryTreeLoader` GCD timer — LL-020,
  `FolderPickerSheet` ancestor walk). Cycle 3 already reviewed these files line-by-line and no code
  has changed since (`git log b840b2a..HEAD` empty).

## NOT WORTH

- [SL-000] LOW / UX — `FileShredderService` partial cancel: shred de N arquivos e cancelar pelo ✕ apaga até o ponto do cancel e o `catch is CancellationError` engole sem um resumo "M de N apagados permanentemente". Não é perda de dados (deleção pedida pelo usuário), só falta feedback; ROI < 1.
- [ML-000] LOW / UX — desfazer um paste-**copy** (`.createFile` por arquivo) não pode ser refeito (`redoable = false`); a origem ainda existe, um action type `.copy(source,dest)` permitiria o redo, mas o ROI de um novo action type é < 1.
- [MM-000] MEDIUM / PERFORMANCE — `LocalHttpServerService+FileStreaming` lê cada chunk de 64 KB (`fileHandle.read`) na serial `queue` dentro do completion do `connection.send`, então um download de uma pasta compartilhada num `/Volumes` lento faz head-of-line block em toda conexão em voo; o directory-listing já foi movido para fora da `queue` (LM-069), o streaming não. ROI 0.56 (precisa de pasta compartilhada em mount lento + clientes concorrentes); sem gatilho de safety-gate.
- [SL-000] LOW / DRY — `DirectoryMonitor` (FSEvents) e `FolderWatcher` (DispatchSource) são dois mecanismos de folder-watch; semânticas genuinamente diferentes (recursivo/path vs. single-dir/fd), combinar adicionaria complexidade.
- [ML-000] LOW / EDGE — o branch temp-hop de case-only-rename em `performRenameOnDisk` também roda em volume case-**sensitive** onde um move direto funcionaria; inofensivo (faz rollback), só um path desnecessário.
- [SL-000] LOW / DRY — `AutoOrganizationSheet.ruleStatusText` cria um `DateFormatter()` por render; modal fora de hot-path, e o lint heurístico disso (`no_formatter_built_in_view`) foi removido de propósito por falso-positivo.
- [ML-000] LOW / EDGE — `NavigationStore` recebe `addToRecents(url)` com o `url` não-standardizado do call site em `AppState+Navigation.completeNavigation` (linha antes de `standardizedURL` ser derivado). `addToRecents` re-standardiza internamente, então efetivamente inofensivo.
- [SL-000] LOW / PERFORMANCE — `FileTaggingService.currentTags` faz um `itemsSnapshot.first(where:)` O(n) por URL alvo dentro de um `Dictionary(...)` map → O(seleção × items); seleções são pequenas na prática.
- [SL-000] LOW / PERFORMANCE — `SystemTagsService.startObserving` observa `NSWorkspace.didActivateApplicationNotification` (`object: nil` — qualquer app), então cada alt-tab entre quaisquer dois apps re-parseia as prefs do Finder (`FavoriteTagNames`, array de 8). `NSApplication.didBecomeActiveNotification` seria suficiente. Parse minúsculo, ROI < 1.

## Suggested New Engineering Rules

### SUGESTÃO DE NOVA REGRA — "Every temp/staging artifact under a user folder has a prefix + a sweep"
- Regra: qualquer código que estaciona um arquivo do usuário (ou um archive em staging) sob nome oculto dentro de um diretório **visível ao usuário** (não `NSTemporaryDirectory()`) DEVE usar uma constante de prefixo compartilhada documentada E ser coberto por um sweep de crash-orphans no ponto de entrada. Novos prefixes entram no sweep na mesma mudança.
- Exemplos: `.wiles-rename-` / `.wiles-replace-` (`sweepStaleRenameTemps`), `.wiles-batch-rename-` (`recoverStrandedStagingTemps`), `.wiles-unzip-` (`sweepStaleUnzipStagingDirs`, round 7). Foi o padrão de CH-190 (sweep apagando dados vivos) e MM-078 (staging sem sweep).
- Deveria virar: code-review rule (não decidível mecanicamente).

### SUGESTÃO DE NOVA REGRA — "A subprocess wait in a service is cancellable or it's a bug"
- Regra: `Process` + `waitUntilExit()` para `ditto`/`zip`/`tar`/`unzip`/`hdiutil` DEVE fazer poll de `Task.isCancelled` + `terminate()` (ou reusar `ArchiveService.runProcess` / `waitForExitOrCancel`), E o wrapper deve ser `CancellableWork.detached` e não `Task.detached` nu (senão `Task.isCancelled` nunca dispara). Blocking em review.
- Exemplos: `ArchiveService.runProcess` (referência); `ArchiveInspectionService` corrigido no round 7 (reusa `waitForExitOrCancel`).
- Deveria virar: SwiftLint custom rule (abaixo, só `warning`) + code-review rule.

## Suggested Lint Rules

### Lint candidate — `bare_process_wait_for_archive_tool`
- Regra proposta: sinalizar `.waitUntilExit()` num arquivo que também constrói um `Process` referenciando `/usr/bin/{ditto,zip,tar,unzip,hdiutil}`, a menos que o mesmo escopo tenha `Task.isCancelled` / `withTaskCancellationHandler` / `waitForExitOrCancel`.
- Detecção: SwiftLint custom rule (precisa de "mesmo arquivo, condição negativa"; regex de 1 linha não expressa a guarda negativa sem falso-positivo).
- Risco de falso-positivo: baixo mas não zero (um one-shot genuinamente rápido, tipo um version probe, dispararia). Dado o bar "100% assertivo / zero falso-positivo": só como `severity: warning` advisory que um `// swiftlint:disable:next` com razão limpa — **não** como `--strict` build-breaking. Ou fica só em checklist de review.

(Nenhuma regra regex nova zero-falso-positivo identificada neste ciclo. CH-190/MM-078/MM-247 são
estruturais, não textualmente detectáveis sem falso-positivo.)

## Files That Could Be Added to IGNORAR.md

Nenhum arquivo novo sugerido neste ciclo. Os ~80 já listados foram re-verificados como triviais no
Cycle 2 e re-conferidos aqui ao lê-los inline (`Constants/*`, enums de `Models/`, structs de dados
de `Features/*`, wrappers de `App/Commands/*`). Candidatos marginais que **não** recomendo adicionar
(carregam invariantes que merecem re-olhar num refactor): `ImageFileType` (define a política
"raster estreito"), `SmartFolderStore` (3 flags de sessão com invariantes documentados),
`KeyboardSelectionNavigator` / `RootDirectoryTreeLoader` / `BoundedFolderNodeCache`.

## NOTA DO PROJETO

### Global — 9.3 / 10
Quarto ciclo consecutivo sem findings de lista principal. Cycle 4 foi o par (incluiu deliberadamente
os ~80 arquivos do `IGNORAR.md` e re-leu linha-a-linha toda a camada de lógica não-view). Densidade
de defeitos essencialmente zero: nenhum `AnyView`, `try!`, `as!`, `fatalError`/`preconditionFailure`
em produção, `print(`, `DispatchQueue.*.sync`, ou lifecycle de singleton `.shared` dirigido por view
per-window em todo o `Sources/`. Quase toda função não-trivial carrega um comentário referenciando o
finding que a endureceu.

### Arquitetura — 9 / 10
Sem mudança de avaliação. A arquitetura própria (facade `AppState` + domain stores; per-window vs
shared classificado explicitamente — R2; Service + SheetView por feature; `CancellableWork` /
`runDetachedFileOperation` como política única de off-main + cancelamento; um catálogo por conceito
de tipo de arquivo) segue coerente e bem defendida. As duas mecânicas de folder-watch
(`DirectoryMonitor` FSEvents / `FolderWatcher` DispatchSource) coexistem por razão legítima. O único
ponto de API privada de dependência (reflection no SwiftTerm) já tem canary CI desde o round 7.

### Código — 9.4 / 10
Sem mudança. Os 3 findings do Cycle 1 (CH-190, MM-143, MM-078) permanecem corrigidos com testes de
regressão (round 7). Tratamento de erro explícito; buffers/coleções alimentados por dados do usuário
quase sempre com cap + sinal de truncamento (`resultsTruncated`, `SearchQueryWarning`,
`wasTruncated`, `isApproximate`, `stdoutTruncated`, listing-truncated note); concorrência estruturada;
`autoreleasepool` em loops de bitmap; hashing em chunks com fallback SHA-256 completo antes de
qualquer deleção. O único MEDIUM em NOT WORTH (`LocalHttpServerService+FileStreaming` head-of-line
block) tem ROI 0.56 e gatilho estreito.

### Produto / negócio — 8.6 / 10
Sem mudança. Feature set amplo (archive, archive-inspector, batch-rename, dup-clean, smart folders,
HTTP share, image convert, PDF merge, auto-org, disk-usage, terminal integrado) com UX defensiva
consistente: confirmações em ações destrutivas (chmod recursivo, empty trash, delete permanente),
notas de "sem undo", sinais de truncamento, Retry em timeout, dimming de favoritos mortos,
`isApproximate` no gráfico de disco.

### Testabilidade estrutural — 9.3 / 10
Sem mudança. Lógica consistentemente extraída para funções puras testáveis com seams de injeção
(`WorkspaceOpening`, `encode:`, `fileManager:`, `modifierFlags:`, `directories:`, `scan:`,
`timeout:`, `startsQuery:`). O canary de reflection do SwiftTerm (round 7) fechou o último buraco.

## FINDINGS skipped by comments in the SOURCE CODE

Nenhum finding foi descartado por causa de um comentário no código-fonte neste ciclo. Onde um
comentário documenta um trade-off aceito e verificado como correto — `CrashReportingConstants` PAT
hardcoded (B1-1), `ImageConverterService` "callers must run inside `Task.detached`" (R3),
`FileSystemStore.tearDown` "synchronous deinit can't touch @MainActor state", `SystemAppearanceObserver`
token nunca removido (singleton app-lifetime), `MainContentView.init` "não chama refresh aqui",
`FinderStyleTruncationService` / `ByteFormat` `nonisolated(unsafe)` + `NSLock` — o comportamento foi
confirmado correto, não foi caso de "ignorei porque tinha comentário".
