# Architecture & Code Review

> Cycle 1 — review skipping files listed in `TODO/eval/IGNORAR.md`.
> Generated incrementally (append-as-analyzed per eval.md). Findings are deleted from this
> file as they are fixed; findings skipped due to genuine doubt remain.

## Findings by ID

_Todos os findings deste ciclo foram corrigidos e removidos. Ver histórico de commits._

## NOT WORTH

- [SL-000] LOW / UX — `FileShredderService` partial cancel: shredding N files then cancelling via the operations ✕ deletes up to the cancel point and `runDetachedFileOperation`'s `catch is CancellationError` swallows it with no "M of N permanently deleted" summary. Not data-loss (user-requested deletion), just missing feedback; ROI < 1.
- [ML-000] LOW / UX — undoing a paste-**copy** (`.createFile` per file) can't be redone (`redoable = false`); the source still exists so a `.copy(source,dest)` action type could redo it, but ROI of a new action type is < 1.
- [MM-000] MEDIUM / PERFORMANCE — `LocalHttpServerService+FileStreaming` reads each 64 KB chunk (`fileHandle.read`) on the serial `queue` in the `connection.send` completion, so one download from a slow `/Volumes` shared folder head-of-line-blocks every other in-flight connection; the directory-listing path was already moved off `queue` (LM-069), streaming wasn't. ROI 0.56 (needs shared folder on a slow mount + concurrent clients); no safety-gate trigger.
- [SL-000] LOW / DRY — `DirectoryMonitor` (FSEvents) and `FolderWatcher` (DispatchSource) are two folder-watch mechanisms; genuinely different semantics (recursive/path vs. single-dir/fd), combining them would add complexity, not remove it.
- [ML-000] LOW / EDGE — `performRenameOnDisk`'s case-only-rename temp-hop branch also runs on a case-**sensitive** volume where a plain move would work (and fails confusingly if a distinct file already occupies the new-cased name); harmless (rolls back), just an unnecessary path.
- [SL-000] LOW / DRY — `AutoOrganizationSheet.ruleStatusText` builds a `DateFormatter()` per render; non-hot-path modal, and the heuristic lint for this (`no_formatter_built_in_view`) was deliberately removed as false-positive-prone.
- [ML-000] LOW / EDGE — `NavigationStore.completeNavigation` calls `navigation.addToRecents(url)` with the non-standardized `url` (line before `standardizedURL` is derived), so a recents dedup can theoretically miss on a trailing-slash / symlink variant. `addToRecents` itself re-standardizes, so effectively harmless.
- [SL-000] LOW / PERFORMANCE — `FileTaggingService.currentTags` does an O(n) `itemsSnapshot.first(where:)` per target URL inside a `Dictionary(...)` map → O(selection × items); selections are small in practice.

## Suggested New Engineering Rules

### SUGGESTION DE NOVA REGRA — "Every temp/staging artifact under a user folder has a prefix + a sweep"
- Regra: any code that parks a user file (or a whole staged archive) under a hidden name inside a **user-visible** directory (not `NSTemporaryDirectory()`) MUST (a) use a documented shared prefix constant, and (b) be covered by a startup/entry-point sweep that recovers or removes stale instances after a crash. New prefixes get added to the sweep in the same change.
- Problema que evita: crash-orphaned staging artifacts that silently consume disk or (worse — CH-190) get deleted by a *sibling* sweep that doesn't know they hold live data.
- Exemplos no projeto: `.wiles-rename-` / `.wiles-replace-` (`sweepStaleRenameTemps`), `.wiles-batch-rename-` (`recoverStrandedStagingTemps`) — covered. `ArchiveInspectionService`'s `.<UUID>_unzip` — **not** covered (MM-078). The `.wiles-replace-` sweep *deleting* live data is CH-190.
- Deveria virar: code-review rule (the "does this new prefix have a sweep, and does an existing sweep now cover data it shouldn't?" check is not mechanically decidable).

### SUGGESTÃO DE NOVA REGRA — "A subprocess wait in a service is cancellable or it's a bug"
- Regra: any `Process` + `waitUntilExit()` in `Sources/` for `ditto`/`zip`/`tar`/`unzip`/`hdiutil` (compress/extract/image work) must poll `Task.isCancelled` + `terminate()` (or reuse `ArchiveService.runProcess`). A bare `waitUntilExit()` on such a tool is a review-blocking finding.
- Problema que evita: "cancel" buttons that do nothing; minutes of background CPU/IO after the UI is gone (MM-078).
- Exemplos: `ArchiveService.runProcess` — correct (reference). `ArchiveInspectionService.extractSingleEntrySync` / `extractSingleEntryViaUnzipPipe` — bare `waitUntilExit()` (MM-078).
- Deveria virar: SwiftLint custom rule (see below) + code-review rule.

## Suggested Lint Rules

### Lint candidate — `bare_process_wait_for_archive_tool`
- Regra proposta: flag a `.waitUntilExit()` call in a file that also constructs a `Process` whose `executableURL`/`arguments` reference `/usr/bin/ditto`, `/usr/bin/zip`, `/usr/bin/tar`, `/usr/bin/unzip`, or `/usr/bin/hdiutil`, unless the same scope also contains `Task.isCancelled` or `withTaskCancellationHandler`.
- Problema que evita: uncancellable long extract/compress subprocess waits (MM-078).
- Exemplo atual: `ArchiveInspectionService.swift` — `process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")` … `process.waitUntilExit()` with no cancellation nearby.
- Detecção automática: sim — regex/AST: file contains one of the 5 tool paths AND a `waitUntilExit(` AND NOT (`Task.isCancelled` | `withTaskCancellationHandler` | `CancellableWork`).
- Regex vs SwiftLint: **SwiftLint custom rule** (needs "same file, two conditions, one negative") — a pure single-line regex can't express the negative guard without false positives.
- Risco de falso positivo: baixo, mas NÃO zero (a genuinely fast one-shot like a version probe would trip it). Given the "100% assertivo / zero falso positivo" bar, ship it only as a `severity: warning` advisory that a `// swiftlint:disable:next` with a reason can clear — or keep it a code-review checklist item. **Do not add as a `--strict` build-breaking rule.**

(No new zero-false-positive regex rule identified this cycle. CH-190 and MM-143 are structural, not textually detectable without false positives.)

## Files That Could Be Added to IGNORAR.md

Nenhum arquivo novo sugerido para `IGNORAR.md` neste ciclo — todos os arquivos de código não-triviais revisados carregam lógica que merece re-revisão. (Vários arquivos triviais de View/modifier já estão no `IGNORAR.md`.)

## NOTA DO PROJETO

### Global — 9.2 / 10
Codebase excepcionalmente maduro e disciplinado. Quase toda função não-trivial carrega um comentário referenciando o finding anterior que a endureceu (`MM-121`, `HM-110`, `LP-012`, `BA-509`, `ML-103`, …). As regras em `.agents/*.md` são seguidas de forma consistente e mecânica. Este ciclo de review encontrou **3 findings de lista principal** em ~42 arquivos de alto risco revisados linha-a-linha + varredura por padrões em todos os 287 — uma densidade de defeitos muito baixa. Nenhum force-unwrap, `try!`, `as!`, `DispatchQueue.sync`, `fatalError` em produção, `@StateObject`/`ObservableObject` legado, ou `AnyView` em todo o `Sources/`.

### Arquitetura — 9 / 10
A arquitetura própria (facade `AppState` sobre domain stores; per-window vs shared explicitamente classificado; Service + SheetView por feature; `CancellableWork`/`runDetachedFileOperation` como política única de off-main + cancelamento) é coerente e bem defendida. O ponto mais fraco é a **fragilidade de reflection no SwiftTerm sem canary** (MM-143) — a única dependência de API privada e a única sem detector de incompatibilidade. Duas mecânicas de folder-watch (`DirectoryMonitor` FSEvents / `FolderWatcher` DispatchSource) coexistem por razões legítimas; não é dívida.

### Código — 9.3 / 10
Tratamento de erro explícito, buffers e coleções alimentadas por dados do usuário quase sempre com cap + sinal de truncamento, concorrência estruturada, `autoreleasepool` em loops de bitmap, hashing em chunks. Os dois furos: (1) `moveItemReplacingSync` entrega dados do usuário sob um prefixo que outro sweep apaga (CH-190) — inconsistência entre dois mecanismos de recovery que isoladamente parecem corretos; (2) `ArchiveInspectionService` não reusa `ArchiveService.runProcess` e reintroduz um `waitUntilExit()` sem cancelamento (MM-078) — regressão de padrão em uma feature mais nova.

### Produto / negócio — 8.5 / 10
Feature set amplo (archive, batch-rename, dup-clean, smart folders, HTTP share, image convert, PDF merge, auto-org, terminal integrado) com UX defensiva (confirmações em ações destrutivas, notas de "sem undo", sinais de truncamento, estados de erro/empty/loading explícitos). Riscos de evolução: CH-190 fica pior à medida que mais gente usa Wiles em shares de rede/drives externos (volumes sem Trash); MM-143 explode silenciosamente no próximo bump de SwiftTerm.

### Testabilidade estrutural — 9 / 10
Lógica consistentemente extraída para funções puras testáveis (`eventTargetsTerminal`, `BatchRenameService.validateTargets`, `SlowVolumePathValidator.*`, `SearchFilterService.*`, seams `modifierFlags`/`encode`/`directories`). MM-143 é o buraco: o caminho de reflection não tem canary.

## FINDINGS skipped by comments in the SOURCE CODE

Nenhum finding foi descartado por causa de um comentário no código-fonte neste ciclo. Onde um comentário documenta um trade-off aceito (ex.: `ImageConverterService` "callers must run inside Task.detached", `FileSystemStore.tearDown` "synchronous deinit can't touch @MainActor state"), o comportamento foi verificado como correto e não gerou finding — não foi um caso de "ignorei porque tinha comentário".
