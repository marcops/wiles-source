# Architecture & Code Review

Formato de cada achado:
`[ID] SEVERIDADE · Categoria · arquivo:símbolo` seguido de
**Problema / Por que / Impacto / Solução / Esforço / Quando**.

IDs: `C#` critical, `H#` high, `M#` medium, `L#` low, `S#` suggestion,
`A#` architectural concern, `O#` overengineering, `B#` bug, `P#` performance,
`U#` product/UX.

---

## Achados (em ordem de revisão)

### Lote 2 — `PreferencesStore.swift` (489 linhas)

**[A2] ARCHITECTURAL CONCERN · SRP · `PreferencesStore.swift` — god object de preferências**
- **Problema:** um único `@Observable` acumula ~10 concerns distintos: view prefs, visibilidade da sidebar, estado de expansão da sidebar, config de busca, translucidez, tamanho de ícone, `favoriteURLs`, `smartFolders` persistidas, `perFolderViewModes`, `listColumnStates`. Já foi partido em `+SmartFolders.swift` por causa do cap de 500 linhas do lint.
- **Por que é problema:** cresce a cada feature; difícil de navegar; toda a lógica de favoritos vive em `AppState+Favorites.swift` mas o dado mora aqui (concern espalhado). `@Observable` mitiga o custo de re-render (tracking por campo), então o problema é manutenção/coesão, não performance.
- **Impacto:** cada nova pref infla o arquivo; o split por lint vai se repetir.
- **Solução:** separar em stores coesos (`ViewPreferences`, `SidebarPreferences`, `SearchPreferences`, `AppearancePreferences`) e mover `favoriteURLs` para um `FavoritesStore` junto da lógica de `AppState+Favorites`. **Custo/migração:** médio — atualizar call sites `appState.preferences.x` → `appState.preferences.view.x` etc.; fazer incremental, um grupo por vez.
- **Quando:** posteriormente; não é urgente, mas decidir a direção antes do próximo split forçado por lint.

### Lote 5 — `AppState+Favorites / +ColumnsAndActions`, `WindowUIState`, `TrashState`

**[M19] MEDIUM · robustez / DRY · `WindowUIState.swift:122-130` — `isAnyModalPresented` é cadeia de ~19 `||`**
- **Problema:** 19 termos OR. `GlobalKeyMonitor` depende dessa propriedade para não deixar teclas "vazarem" para a lista quando um modal está aberto. Cada novo sheet/alert **precisa** ser lembrado aqui, senão vira bug de teclado (Return/Delete atinge a lista atrás do alerta).
- **Por que é problema:** viola DEV_RULES "No Inline Compound Conditions" (≥3); manutenção frágil de alto impacto.
- **Solução:** modelar as apresentações como uma coleção (`Set<ModalKind>` / contador incrementado no `.sheet`/`.alert` wrappers) ou, no mínimo, quebrar em `anySheetPresented`/`anyAlertPresented`/`anyItemSheetPresented` com poucos termos cada e somar as três.
- **Esforço:** médio. **Quando:** posteriormente (mas é dívida real).

**[M20] MEDIUM · consistência · `WindowUIState.swift:24-63` — 2 padrões misturados para apresentar sheet**
- **Problema:** alguns sheets usam `showXSheet: Bool`, outros usam `xURL: URL?` / `xItem: FileItem?` como sinal de presença. O comentário de `httpShareFolderURL` diz que o padrão de payload opcional é melhor ("'sheet shown, no folder' não pode mais acontecer"). Os `Bool` que carregam dado implícito são o padrão legado pior.
- **Impacto:** estados impossíveis possíveis nos sheets baseados em `Bool` + payload separado; API interna inconsistente.
- **Solução:** todo sheet que carrega dado migra para `payload: X?`; `Bool` só para sheets sem dado (Help/About/Settings/Feedback).
- **Esforço:** médio. **Quando:** posteriormente.

### Lote 8 — `SearchFilterService`, `DirectoryCacheService`, `FolderWatcher`

**[M31] MEDIUM · performance · `SearchFilterService.swift:101-217` — N+1 de `resourceValues` por token de filtro**
- **Problema:** `matchesDateFilter`, `matchesSizeFilter`, `matchesKindFilter(folder)`, `matchesTagFilter` cada um faz seu próprio `fileURL.resourceValues(forKeys:)`. Uma query `date:>7d size:>1m kind:folder` = 3+ syscalls por arquivo candidato, e `matchesSearch` roda antes de o `FileItem` (que já buscaria tudo num batch) existir.
- **Impacto:** busca com filtros sobre pasta/árvore grande fica lenta (syscall storm).
- **Solução:** `matchesSearch` faz **um** `resourceValues(forKeys:)` com todas as chaves que os tokens presentes exigem e passa os valores para os matchers.
- **Esforço:** médio. **Quando:** posteriormente (junto de [H1]/[M30]).

**[M32] MEDIUM · manutenção / correção · `SearchFilterService.swift:190-210` — listas de extensão hardcoded para `kind:image/doc/code/archive`**
- **Problema:** arrays literais de extensões ("png","jpg",...) que vão ficar desatualizados (sem avif, jxl, mkv, webp já ok mas parcial) e provavelmente duplicam listas em `ThumbnailService`/`ImageConverterService`/ícone de `FileItem`.
- **Por que é problema:** mesmo espírito do "never hardcode the set of X" das regras; `UTType(filenameExtension:)?.conforms(to: .image/.sourceCode/.archive)` é auto-mantido e mais correto.
- **Impacto:** `kind:image` não acha um `.avif`; manutenção multiplicada.
- **Solução:** trocar por checagem via `UTType` conformance; centralizar qualquer lista que reste.
- **Esforço:** baixo/médio. **Quando:** posteriormente.

**[M34] MEDIUM · arquitetura · dois mecanismos de watch de pasta: `DirectoryMonitor` (FSEvents) e `FolderWatcher` (DispatchSource)**
- **Problema:** `DirectoryMonitor` (1 pasta, FSEvents, usado por `FileSystemStore`) e `FolderWatcher` (N pastas, `DispatchSource`+fd por pasta, usado por auto-org). Capacidades diferentes (FSEvents cobre árvore; DispatchSource é 1 fd/pasta e não pega subdirs) — manter os dois é defensável, mas a lógica de debounce e o contrato ("pasta X mudou") deveriam ser um só.
- **Impacto:** dobra a superfície de bugs de lifecycle de watcher (a parte mais arriscada do app).
- **Solução:** extrair um protocolo `FolderChangeObserver` comum + `Debouncer` compartilhado ([M33]); duas implementações atrás dele.
- **Esforço:** médio. **Quando:** posteriormente.

**[L30] LOW · UX · `SearchFilterService.swift:242-249` — content search silenciosamente no-op para query < 3 chars, e regex inválida (`r:[`) vira zero resultados sem aviso.** Surfacar "digite ao menos 3 caracteres" / "regex inválida".

**[L31] LOW · edge · `SearchFilterService.matchesContent` — `String(contentsOf:encoding:.utf8)` falha silenciosamente em arquivo texto não-UTF8 (Latin-1); e lê até 2MB por arquivo em série.**

**[L32] LOW · robustez · `FolderWatcher.swift:48-50` — `open()` que falha (`fd == -1`) faz `return` mudo; pasta de regra em volume desmontado deixa de ser observada sem log.**

**[L33] LOW · consistência API · `SearchFilterService` mistura `fileURL.resourceValues` (URL) e `(fileURL as NSURL).resourceValues` (NSURL).**

**DirectoryCacheService.swift — praticamente sem achado.** `NSCache` com `countLimit`+`totalCostLimit`, TTL via `isStale`, `@unchecked Sendable` legítimo. LOW: caminhos de mutação (paste/delete/move) não chamam `invalidate`, então há ~1 frame de conteúdo stale possível ao renavegar em <30s (o load async reconcilia).

### Lote 11 — `NetworkDiscovery/Server`, `OpenWith`, `PDFMerge`, `POSIXPermissions`, `FilePermissions`, `Symlink*`, `PermissionService`

**[M43] MEDIUM · rules violation · hooks "test-only" em `Sources/`**
- **Problema:** DEV_RULES: "Production source code never bends to accommodate a test... No test-only branches, hooks, flags". Exemplos: `PermissionService.markFullDiskAccessPromptAsShown()` ("Test-only helper"), `PermissionService.resetInitialPermissionsFlag()`, `AutoOrganizationService.scheduleProcessFolder` ("also invoked directly by tests"), `AppState.handleSelection(for:modifierFlags:)` ("Testable seam").
- **Por que é problema:** regra dura do projeto; alguns são DI seams legítimos (`WorkspaceOpening`), mas helpers de conveniência de teste em `public` de produção não são.
- **Solução:** mover para os testes (extensões em `Tests/`), ou reformular como API de produção genuína (ex.: `resetInitialPermissionsFlag` só faz sentido se houver um botão real de "remostrar prompt" nas Settings — aí vira feature, não hook).
- **Esforço:** baixo. **Quando:** posteriormente.

**[M44] MEDIUM · UX / produto · `PermissionService.swift:38-53` — prompt de Full Disk Access é one-shot no launch**
- **Problema:** `hasShownFullDiskAccessPromptKey` é setado antes de checar acesso; quem clica "Not Now" nunca mais é perguntado, mesmo ao bater num erro de permissão real depois.
- **Solução:** além (ou em vez) do prompt de launch, oferecer o CTA de FDA contextualmente quando uma operação falha por permissão (`AsyncErrorStateView`/alerta de erro), e um botão nas Settings.
- **Esforço:** médio. **Quando:** posteriormente (decisão de produto).

### Lote 13 — serviços restantes (`SystemAppearance/Tags`, `FileTagging`, `CopyPath`, `Bundle+`, `HTMLEscaping`, `L10n+Lookup`, `AppLanguage`, `NewFileTemplate`, `TemplateRendering`, `FileShredder`)

**[M49] MEDIUM · correção / segurança · `CopyPathService.swift:46-51` — `escapeForTerminal` incompleto; a variante segura `posixSingleQuoted` não é usada pelo menu**
- **Problema:** `escapeForTerminal` (usada por `PathCopyVariant.terminalEscaped`, o item de menu "copiar caminho, escapado p/ terminal") não escapa `~` (expandido pelo shell no início de token não-citado) nem newline (nome de arquivo com `\n` é legal no macOS). `posixSingleQuoted` — mais robusta — existe mas não alimenta o menu.
- **Por que é problema:** colar o caminho "escapado" de um arquivo `~algo` ou com newline no terminal executa algo diferente do pretendido.
- **Impacto:** comando de terminal errado/quebrado a partir de nome de arquivo hostil ou incomum.
- **Solução:** o menu usa `posixSingleQuoted` (single-quote é à prova de tudo exceto `'`, já tratado); ou completar `escapeForTerminal` com `~` e `\n`.
- **Esforço:** baixo. **Quando:** agora.

**[M50] MEDIUM · performance · `SystemTagsService.swift:15-32` — `favoriteTags` é computed que relê `com.apple.finder` a cada acesso; `color(forTagNamed:)` relê tudo por chamada**
- **Problema:** `UserDefaults(suiteName: "com.apple.finder")?.stringArray(...)` + parse em toda leitura. Se `color(forTagNamed:)` roda por arquivo por render (pontinhos de tag), é leitura de domínio cross-app por célula por frame.
- **Solução:** cachear `favoriteTags` (TTL curto ou invalidar via notificação de mudança de prefs do Finder). Confirmar se a UI de linha usa `FileItem.tagColor` (já pronto) em vez disso.
- **Esforço:** baixo. **Quando:** posteriormente (verificar `TagsIndicatorView`).

**[M51] MEDIUM · L10n · `AppLanguage.swift:27` — `displayName` de `.system` = `"System Default"` hardcoded em inglês**
- **Problema:** os demais casos são endônimos (correto não traduzir); mas "System Default" é texto de UI e deve passar por `L10n`.
- **Impacto:** um item do seletor de idioma sempre em inglês.
- **Solução:** `case .system: L10n.string(.languageSystemDefault, lang: currentLang)` (precisa threadar o lang atual, ou resolver no call site).
- **Esforço:** baixo. **Quando:** posteriormente.

**[L50] LOW · segurança (injeção de template) · `TemplateRenderingService.render` — aplica `replacingOccurrences` de `{{KEY}}` em passes sucessivos sobre o template inteiro; um valor dinâmico (nome de arquivo, servido via LAN por `LocalHttpServerService`) contendo `{{OUTRACHAVE}}` pode ser substituído num pass seguinte.** Fazer substituição em passe único (regex `{{(\w+)}}` → lookup) ou escapar `{`/`}` nos valores.

**[L51] LOW · perf · `FileTaggingService.toggleTag` constrói `FileItem(url:, fetchTags:true)` completo (batch de 11 chaves + tags) só para ler `.tags` quando a URL não está no snapshot.** Ler `.tagNamesKey` direto.

**[S2] SUGGESTION · `AppLanguage.allCases` vs `Resources/*.lproj` — adicionar teste (quando testes forem escritos) que afirma que o enum e as pastas `.lproj` no disco batem exatamente, para pegar drift (relacionado ao incidente do `shortcutsAllTab` cru que já foi pro app).**

**[L52] LOW · doc drift · `Bundle+WilesResources.swift` cita `scripts/build_release.sh`; `WILES_RULES.md` lista `build_debug_app.sh`/`push_and_relaunch.sh`, não `build_release.sh`.**

### Lote 14 — `Constants/`, `App/WilesApp.swift`, `App/Commands/*`

**[C1] CRITICAL · segurança · `CrashReportingConstants.swift:15` — GitHub PAT hardcoded e distribuído no binário**
- **Problema:** um fine-grained PAT (`github_pat_…`) com `Issues: Read and write` no repo público `marcops/wiles` está em texto no código (com `swiftlint:disable no_hardcoded_secrets`). Vai em todo `.app` shipado — `strings Wiles.app/Contents/MacOS/Wiles | grep github_pat` extrai.
- **Por que é problema:** qualquer pessoa que baixe o Wiles obtém um token que pode **ler todas as issues** (incl. dados que usuários colam em crash reports — paths, nomes de arquivo, às vezes conteúdo), **criar/fechar/editar issues** (spam, apagar relatórios, DoS do tracker). O token já está no histórico git — rotacionar exige revogar + reescrever histórico.
- **Impacto:** exposição de dados de usuários nos crash reports; vandalismo do issue tracker; o token é abusável até ser revogado.
- **Solução:** o `.app` não deve carregar credencial de escrita. Opções, dado "sem servidor/sem conta paga Apple": (a) um relay serverless mínimo (Cloudflare Worker / Vercel free) que guarda o token e recebe `POST /report` do app — o app não carrega segredo nenhum; (b) se mantiver hardcoded como risco aceito: revogar e emitir novo com o **mínimo** escopo, monitorar uso, ter runbook de rotação, e nunca colocar dados sensíveis não redigidos no corpo da issue (redigir paths/usernames no cliente antes de enviar).
- **Esforço:** médio (relay) / baixo (redigir + rotacionar).
- **Quando:** agora — decidir a direção com o usuário; é dado de terceiros exposto.

**[M52] MEDIUM · perf / UX de launch · `WilesApp.swift:10-31` — `App.init()` faz muito trabalho síncrono, incluindo um `NSAlert` modal**
- **Problema:** `init()` roda `GitBeacon.configure`+`installCrashHandler`, `PermissionService.requestInitialPermissions` (que em 1º launch sem FDA faz **`alert.runModal()` síncrono** — congela o launch até o clique) e `probeProtectedFolders` (6 `isReadableFile` todo launch), `AutoOrganizationService.shared.startMonitoring()` (carga de regras + symlink-resolve I/O, ver [M41]).
- **Por que é problema:** `App.init` do SwiftUI pode ser chamado em momentos não óbvios; efeitos colaterais pesados ali são footgun conhecido (memória "SwiftUI init() side effects"). O modal síncrono trava o primeiro frame.
- **Solução:** mover setup de launch para `applicationDidFinishLaunching` (via `NSApplicationDelegateAdaptor`) ou um `.task` no root view; o prompt de FDA como sheet assíncrono, não `runModal`.
- **Esforço:** médio. **Quando:** posteriormente.

**[M53] MEDIUM · bug / UX multi-janela · `WilesApp.swift:87` — `setFrameAutosaveName("WilesMainWindow")` idêntico para toda janela**
- **Problema:** todo `NSWindow` recebe o mesmo autosave name → todas competem pelo mesmo frame salvo; abrir a 2ª janela pode encaixá-la sobre a 1ª, e a restauração entre launches fica ambígua com N janelas.
- **Impacto:** janelas empilhadas/posicionadas errado no multi-window.
- **Solução:** autosave name único por janela (ex.: sufixo com um contador/scene id), ou nenhum e posicionar via cascade manual.
- **Esforço:** baixo. **Quando:** posteriormente.

**[M54] MEDIUM · perf · `WilesApp.swift:73-90` — `.onAppear` recarrega o app icon do disco e reconfigura janelas a cada nova janela**
- **Problema:** `.onAppear` roda por janela (Cmd+N). `NSImage(contentsOf: iconURL)` (leitura de disco) + `NSApplication.shared.applicationIconImage = ...` refeito toda vez; loop sobre `NSApplication.shared.windows` reconfigurando todas.
- **Solução:** setar o ícone e o que é app-global uma única vez (flag, ou no delegate `didFinishLaunching`); no `.onAppear` só o que é da janela nova.
- **Esforço:** baixo. **Quando:** posteriormente.

**[M55] MEDIUM · rules violation · branch `--ui-testing` em `WilesApp.swift:24`**
- **Problema:** `CommandLine.arguments.contains("--ui-testing")` gateia `requestInitialPermissions` — branch condicional de produção só para acomodar UI test. DEV_RULES: "No test-only branches ... in `Sources/`". Consolidar com [M43].
- **Solução:** a UI test injeta um estado (defaults pré-setados via launch environment) que faz o caminho normal ser no-op, sem `if --ui-testing` no source.
- **Esforço:** médio. **Quando:** posteriormente.

**[L53] LOW · consistência · `AsyncDelayTokens.swift` mistura `TimeInterval`, `UInt64` (nanos crus `3_000_000_000`) e `Duration` para a mesma categoria de valor.** Padronizar em `Duration` (`.seconds`/`.milliseconds`).

**[L54] LOW · dead key? · `DefaultsKey.smartFolders` — smart folders são persistidas por `SmartFolderService`, não via essa chave. Auditar/remover chaves não usadas.**

**[L55] LOW · consistência · `EditMenuCommands` — cut/copy têm `.disabled(seleção vazia)`, paste não tem `.disabled` nenhum.**

**[L56] LOW · reforça [M49] · `ToolsMenuCommands` "Copy Path ▸ Terminal" usa `variant: .terminalEscaped` (o escaper incompleto).**

### Lote 15 — `BatchRename`, `ImageConverter`, `ArchiveInspector`

**[M56] MEDIUM · L10n (sistêmico) · mensagens de falha parcial hardcoded em inglês chegam a alertas**
- **Problema:** `BatchRenameResult.failureSummaryMessage` (`"\(x) of \(y) items renamed. Failed — …"`), `FileShredderService.summarizeFailures`, `AppState+Operations` (`"\(n) of \(m) items could not be pasted."`), `SymlinkService` (`"Cannot create a symlink…"`), `WilesError.operationFailed(reason:)` em vários pontos, `WilesError.errorDescription` (todo inglês). Todas viram texto de alerta pro usuário.
- **Por que é problema:** viola SWIFT_LANG_RULES "Zero Hardcoded User-Facing Text"; usuário não-inglês vê inglês em falhas.
- **Impacto:** inconsistência de idioma exatamente nos momentos de erro.
- **Solução:** essas mensagens viram `WilesError.localized(key:arguments:)` com chaves de contagem (`"%1$d de %2$d…"`). Candidato a lint: literal de string passada a `showError(...)`/`operationFailed(reason:)`.
- **Esforço:** médio. **Quando:** posteriormente.

### Lote 16 — `DuplicateDetectionService`, `DiskSpaceVisualizerService`, `DiskUsageItem`, `SmartFolderService`

**[M64] MEDIUM · complexidade · `SmartFolderService.runQuery` — juggling manual de `NSMetadataQuery` + `NotificationCenter` com 3 níveis de `Task { @MainActor [weak self] }` aninhados e remoção de observer em 3 pontos**
- **Problema:** difícil de auditar; observer removido antes de adicionar, dentro do Task, e implicitamente ao parar. `swiftformat:disable redundantSelf` (ver [M21]).
- **Solução:** encapsular numa pequena classe `SpotlightQuery` com `async` API (`func run() async -> [URL]`) que gerencia observer+stop internamente com `withCheckedContinuation` + `defer` de cleanup garantido.
- **Esforço:** médio. **Quando:** posteriormente.

**[L62] LOW · magic numbers · `DiskSpaceVisualizerService.buildReport:73` — array de 10 hues `[0.60, 0.38, …]` sem nome; `colorHue: 0.0` para "Others".**

**[L63] LOW · access control · `DiskUsageItem.name` é `let` (internal) enquanto os demais campos são `public let` (mesma inconsistência de [5]).** `ByteCountFormatter` no `init` (tema recorrente).

**[M43 +=] `SmartFolderService.saveSmartFolders(_:encode:)` — mais um "Test-only seam" em `Sources/` (com justificativa razoável); somar ao inventário de [M43].**

### Lote 17 — `LocalHttpServerService.swift` (493 linhas)

**[M65] MEDIUM · concorrência · `LocalHttpServerService` — `@Observable` de isolamento misto**
- **Problema:** `isRunning`/`serverURL`/`startError` são `@MainActor`; `sharedFolder`/`port`/`requiredPassword`/`listener`/`connections`/`requestBuffers` são acessados na `queue` (DispatchQueue própria). A classe é `@Observable` + `@unchecked Sendable`. Mutar `sharedFolder` (que é `public var`, sem `@MainActor`) via `queue.sync` dispara notificação de Observation a partir de thread de background — SwiftUI observando `service.sharedFolder` recebe mudança fora da main.
- **Por que é problema:** Observation não é thread-safe fora da main; `@unchecked Sendable` esconde isso do compilador (mesma família de [A1]).
- **Impacto:** re-render/crash intermitente se alguma view observar as propriedades não-`@MainActor`.
- **Solução:** separar a superfície observável (só `@MainActor`, atualizada via `Task { @MainActor }`) do estado interno do servidor (numa classe/`actor` não-observável). Ou tornar tudo `@MainActor` e a `queue` só lê snapshots imutáveis passados na criação.
- **Esforço:** médio. **Quando:** posteriormente.

**[M66] MEDIUM · produto / UX · `streamFile` — sem suporte a `Range`/`206`, `Content-Type` sempre `application/octet-stream`**
- **Problema:** todo GET manda o arquivo inteiro do byte 0. Download de 4GB interrompido recomeça do zero; seek de vídeo no navegador não funciona; imagens/PDF/texto baixam em vez de abrir inline.
- **Por que é problema:** é uma feature de compartilhamento de arquivos; resume e preview inline são expectativa básica.
- **Solução:** honrar `Range:` (responder `206 Partial Content` + `Content-Range`, anunciar `Accept-Ranges: bytes`); mapear `Content-Type` por extensão via `UTType`.
- **Esforço:** médio. **Quando:** posteriormente.

**[L64] LOW · segurança / UX · senha via HTTP Basic em HTTP puro na LAN — cleartext no fio**
- **Problema:** `constantTimeEquals` protege contra timing no servidor, mas a senha vai base64 (não cifrada) sobre HTTP sem TLS; qualquer um no mesmo Wi-Fi faz sniff. Também: a comparação de **tamanho** não é constant-time (vaza o comprimento).
- **Solução:** não há TLS fácil sem cert; então o `HttpShareSheet` deve deixar claro ("a senha impede acesso casual, não um sniffer de rede").
- **Esforço:** baixo (texto). **Quando:** posteriormente.

**[L65] LOW · UX · `port = 8080` fixo, sem fallback** — se 8080 estiver ocupada, `NWListener` falha e mostra `startError` sem tentar outra porta. Usar porta 0 (OS escolhe) ou varrer um range.

**[L66] LOW · bug menor · `sendNextChunk` / `streamFile` — erro de leitura no meio é tratado como EOF; cliente recebe arquivo truncado com `Content-Length` que não bate (ele detecta, mas sem erro do lado servidor).**

**[L67] LOW · robustez · path com null byte / `//` no request — `appendingPathComponent` + C API do `FileManager` podem truncar no `\0`. O guard de traversal com `resolvingSymlinksInPath` provavelmente cobre, mas vale rejeitar explicitamente `\0` e componentes vazios.**

### Lote 18 — `Views/Content/` núcleo (`MainContentView`, `FileCollectionContainerView`, `FileGridView`, `FileListView`, `FileGridCardItemView`)

**[M67] MEDIUM · performance · `MainContentView.swift:83-85` — mudar `sortOption`/`sortAscending` faz re-leitura de disco**
- **Problema:** `.onChange(of: sortOption)` e `.onChange(of: sortAscending)` chamam `refreshCurrentDirectory()`, que re-enumera o diretório inteiro do disco só para reordenar. `sortAscending` também não muda o conjunto de arquivos.
- **Por que é problema:** trocar de "Nome" para "Data" numa pasta de 10k arquivos re-faz o `contentsOfDirectory` + N `FileItem` + N `resourceValues` — trabalho de I/O totalmente evitável.
- **Impacto:** lag ao mexer no sort em pastas grandes / disco lento.
- **Solução:** para mudança só de ordenação, re-ordenar `fileSystem.items` em memória via `FileSystemService.sortItems(...)` sem tocar o disco. `showHiddenFiles` continua precisando de re-leitura (conjunto diferente).
- **Esforço:** baixo. **Quando:** agora.

**[M68] MEDIUM · performance · `ClipboardState.isCut` O(n) chamado por linha por render (`FileListView.swift:122`, `FileGridCardItemView.swift:19`)**
- **Problema:** cada linha/célula visível avalia `appState.transient.clipboard?.isCut(url: item.url)`, que faz `urls.contains(...)` linear. Lista de 500 linhas × tamanho do clipboard, a cada render.
- **Por que é problema:** confirma o achado do `ClipboardState` na revisão do IGNORAR — agora com o call site: é caminho de render quente.
- **Solução:** `ClipboardState` guarda um `Set<URL>` interno (normalizado) para lookup O(1); `isCut` vira `set.contains(url.standardizedFileURL) && action == .cut`.
- **Esforço:** baixo. **Quando:** agora.

**[L68] LOW · dois handlers para a tecla Delete · `MainContentView.keyboardShortcutsHandler` tem `.onDeleteCommand { deleteSelected }` e `FileMenuCommands` tem `Button(moveToTrash).keyboardShortcut(.delete)`.** Coordenado via `isAnyModalPresented`/`GlobalKeyMonitor`, mas é frágil — consolidar num só ponto.

**[L69] LOW · perf menor · `FileGridView.renameFieldOverlay`/`revealFieldOverlay` fazem `items.first(where:)` (O(n)) em `body`; `revealFieldOverlay` chama `FinderStyleTruncationService.wrappedLines` em `body` (reforça [M46]).**

### Lote 19 — `Views/Content/` teclado + wiring de modais

**[A3] ARCHITECTURAL CONCERN · roteamento de teclado espalhado por 3 mecanismos**
- **Problema:** atalhos/teclas são tratados em (1) `GlobalKeyMonitor` (monitor `NSEvent` local) → `KeyboardSelectionNavigator`/`KeyboardZoomController`, (2) `MainContentView.keyboardShortcutsHandler` (Buttons SwiftUI ocultos + `.onDeleteCommand`), (3) os 7 `*MenuCommands` (`.keyboardShortcut`). Precedência: o monitor roda primeiro e engole (`return nil`) o que trata; os outros só veem o que sobra.
- **Por que é problema:** difícil raciocinar sobre qual caminho trata cada tecla em cada estado (foco em text field, modal aberto, `navigationMode`); Delete tem 3 handlers; a "cheat sheet" de atalhos pode divergir do real; adicionar/mudar um atalho exige checar 3 lugares.
- **Impacto:** bugs de atalho dependentes de foco/estado; manutenção cara.
- **Solução:** um único roteador de comandos (uma tabela `keyCode+modifiers → Command`), consultado pelo monitor; os menus expõem os mesmos `Command`s. `MainContentView` para de ter Buttons ocultos.
- **Esforço:** médio/alto. **Quando:** posteriormente (dívida arquitetural real, não urgente).

**[M70] MEDIUM · arquitetura / simplificação · camada de apresentação de modais fragmentada**
- **Problema:** `WilesModalSheets` + `WilesModalSheetsSecondary` + `WilesModalAlerts` — **split por limite de linha do lint** (`function_body_length`), não por coesão. ~18 sheets. Mistura `.sheet(item:)` com `.sheet(isPresented: Binding(get:{x != nil}, set:{...}))` (4× repetido para payloads opcionais). E `WindowUIState.isAnyModalPresented` tem que enumerar todos os 19 ([M19]).
- **Por que é problema:** "componentes que deveriam ser combinados"; o código pode ser bem mais simples.
- **Solução:** um `enum ActiveModal: Identifiable { case properties(FileItem), help, imageConverter(FileItem), inspectArchive(URL), … }` em `WindowUIState` + **um** `.sheet(item: $windowUIState.activeModal)` com `switch`. `isAnyModalPresented` vira `activeModal != nil`. Os 3 arquivos + a cadeia de 19 `||` colapsam.
- **Esforço:** médio. **Quando:** posteriormente.

**[M71] MEDIUM · retain cycle frágil · `IntegratedTerminalView.Coordinator.parent` (strong) ↔ `WindowUIState.terminalViewCache.coordinator`**
- **Problema:** `windowUIState` → `terminalViewCache` (`let`) → `coordinator` (`var`) → `parent: IntegratedTerminalView` (struct com refs a `appState`/`windowUIState`) → `windowUIState`. Ciclo quebrado só manualmente em `TerminalViewCache.tearDown()` (chamado de `MainContentView.onDisappear`).
- **Por que é problema:** se `tearDown()` não rodar (algum caminho de dismiss), `WindowUIState` + `AppState` + o terminal inteiro vazam por janela.
- **Solução:** `Coordinator` guarda `weak var windowUIState`/`appState` (ou só o que precisa) em vez de `parent` inteiro strong.
- **Esforço:** baixo. **Quando:** posteriormente.

**[M72] MEDIUM · bug · `CursorModifier.swift` — `NSCursor.push()/pop()` podem desbalancear**
- **Problema:** `onHover { inside ? cursor.push() : NSCursor.pop() }`. Se a view é removida enquanto hovered (sem `onDisappear` que faça `pop`), o cursor fica preso (ex.: resize cursor); dois hover-enter sem exit (acontece no SwiftUI) empilham 2 push e 1 pop.
- **Impacto:** cursor errado "grudado" na UI. (Já sinalizado como problema na nota antiga do IGNORAR.)
- **Solução:** rastrear estado de push, `pop` em `onDisappear`, ou usar `NSTrackingArea`/`cursorUpdate` (o jeito robusto no AppKit).
- **Esforço:** baixo. **Quando:** agora.

**[M73] MEDIUM · performance · `FileListHeaderView` — clique em header e resize de janela persistem coluna a cada frame**
- **Problema:** (a) `headerCell` faz `refreshCurrentDirectory()` no clique **e** a mudança de `sortOption` dispara `MainContentView.onChange(of: sortOption)` → **outro** `refreshCurrentDirectory()` (duplo, reforça [M67]). (b) `adjustNameColumnWidth` roda no `onGeometryWidthChange` com `setColumnWidth(.name, persist: true default)` → `listColumnStates` didSet → `JSONEncoder().encode` + `UserDefaults.set` **por frame** durante o drag de resize da janela.
- **Solução:** (a) só um `refreshCurrentDirectory` por mudança de sort (ou re-sort em memória, [M67]); (b) `adjustNameColumnWidth` usa `persist: false` e persiste uma vez no fim do resize.
- **Esforço:** baixo. **Quando:** agora.

**[L70] LOW · `IntegratedTerminalView` — `/bin/zsh` hardcoded (ignora `$SHELL`); `exit` interativo respawna shell (nunca "fecha" via exit).**

**[L71] LOW · magic number `+ 44` repetido em `FileListHeaderView.totalColumnsWidth`/`adjustNameColumnWidth`; `visibleColumns(appState)` recomputado em muitos pontos.**

**[L72] LOW · DRY · padrão `.sheet(isPresented: Binding(get:{x != nil}, set:{if !$0 {x = nil}}))` 4× — envolver o payload num struct `Identifiable` e usar `.sheet(item:)`.**

### Lote 20 — `Views/Components/` interação (`FileItemInteractionsModifier`, `SharedFileItemContextMenu`, `InlineRenameField`, `SelectionRectangleOverlay`, `MultiFileDragView`, `SelectionAwareNameText`, `ClickOutsideDetector`)

**[M74] MEDIUM · performance · `SharedFileItemContextMenu.openWithMenuContent:195` — `OpenWithService.availableApplications` roda em `body` (LaunchServices + N `Bundle`/`resourceValues`, síncrono no MainActor)**
- **Problema:** abrir o menu de contexto num arquivo enumera todos os apps handler via `NSWorkspace.urlsForApplications(toOpen:)` + por app: `Bundle(url:)`, `resourceValues([.effectiveIconKey])`, `FileManager.displayName`, e `icon.size = 16×16`.
- **Impacto:** menu de contexto "engasga" ao abrir para tipos com muitos apps; jank.
- **Solução:** `availableApplications` assíncrono + cache por extensão; construir o submenu `.task`-driven.
- **Esforço:** médio. **Quando:** posteriormente.

**[M75] MEDIUM · DRY · dicas de atalho hardcoded no `SharedFileItemContextMenu` duplicam as definições reais de `.keyboardShortcut`**
- **Problema:** `"Space"`, `"Cmd+X"`, `"Cmd+C"`, `"Cmd+V"`, `"Opt+Cmd+Del"`, `"Cmd+I"`, `"F2"`/`"Return"` são strings fixas no menu; os atalhos reais vivem em `*MenuCommands`/`GlobalKeyMonitor`. Divergem se um atalho mudar.
- **Solução:** derivar de um registro central de atalhos (liga-se a [A3]).
- **Esforço:** médio. **Quando:** posteriormente.

**[L73] LOW · UX / bug de texto · `SharedFileItemContextMenu.contentActionsSection:83` — dica de atalho `"#10"` para "Copy Content"** — parece placeholder/typo; vira "(#10)" visível ao usuário. Não há atalho real; passar `shortcut: ""` ou remover a dica.

**[L74] LOW · UX · `InlineRenameField` / `performRename` não valida nome de arquivo** — digitar `a/b` ou `:` cria/erra em vez de sanitizar como o Finder (`:`↔`/` swap, rejeitar `/`). Erro cru para o usuário.

**[L75] LOW · perf/complexidade · `FileItemInteractionsModifier` empilha 7 camadas de gesto/interação por linha (2 taps + drag + `RightClickDetector` + `MultiFileDragView` + `.contextMenu` + `.springLoadedFolder`) × N células visíveis.** É o componente compartilhado que as regras exigem (DRY ok), mas a densidade de recognizers por célula é alta. Monitorar se vira gargalo em grids grandes.

**[L76] LOW · consistência · `SharedFileItemContextMenu` — `ShareLink(item:)` rotulado `tr(.services)` (semântica estranha: ShareLink é o share sheet, não o menu Services); `imageFileExtensions` hardcoded (reforça [M32]/[M48]); "Merge into PDF" aparece para 1 arquivo só.**

### Lote 21 — `Views/Components/` batch 3 (async/pagination/scroll/detectors/operations popover)

**[M40 reforçado]** `ImageThumbnailView.init:14` — chama `ThumbnailService.shared.cachedThumbnail(for:size:)` como `@State(initialValue:)`, e `cachedThumbnail`→`cacheKey` faz um `stat` (`resourceValues([.contentModificationDateKey])`). Ou seja: **um `stat` síncrono no init de cada célula de imagem**, refeito a cada create/destroy de célula no scroll do `LazyVGrid`. Confirma [M40].

**[L77] LOW · UX · `ResetPaginationAndPrefetchThumbnails.thumbnailPrefetchItemThreshold = 500` — só faz prefetch de thumbnails em pastas com >500 itens.** Pasta com 400 imagens não recebe prefetch → thumbs aparecem devagar no scroll. Lógica meio invertida (prefetch beneficia mais pastas de imagem menores).

**[L78] LOW · redundância · `ScrollerAutoHideSetter()` é colocado `.background(...)` 3× em `FileCollectionContainerView` (linhas ~50/60/75).** Três instâncias procurando e configurando o mesmo `NSScrollView`. Uma deve bastar.

**[L79] LOW · doc drift · `PaginatedItemsSection.lazyLoadingBatchSize` é `static var {100}` "porque `static let` não é permitido em tipo genérico" (permitido em Swift moderno); comentários de `AsyncResultView`/`ResetPagination` citam `LayoutTokens.lazyLoadingBatchSize` que não existe em `LayoutTokens`.**

**[L80] LOW · perf menor · `PaginatedItemsSection.visibleItems` faz `Array(items.prefix(visibleLimit))` a cada `body` quando paginando (>500 itens).**

**[L81] LOW · `FileItemIconView`/`ThumbnailService.supportsThumbnail` — `UTType(filenameExtension:)` + 5 `conforms(to:)` por ícone por render (reforça [M48]; precomputar no `FileItem`).**

**[L82] LOW · `FileItemIconView.openFolderIcon` — `perform(NSSelectorFromString("iconForFileType:"))` + `takeUnretainedValue()` (API legada por dynamic dispatch p/ evitar warning de deprecação); funciona mas é frágil.**

### Lote 22 — `Views/Components/` shared (menus, chrome, KeyLabel, ShortcutsHUD, Tags, Modal scaffold, Theme)

**[M50 confirmado/elevado]** `TagColor.swift:27` `colorForTag(_:)` → `SystemTagsService.color(forTagNamed:)` → `favoriteTags` (lê `com.apple.finder` UserDefaults + parseia array de 8 slots) — chamado **por tag, por linha, por render** via `TagsIndicatorView` (grid + list). Com `showTags` ligado numa pasta de 500 arquivos com 2 tags cada: ~1000 leituras cross-app de UserDefaults + parse por frame. É bug de render-path real — cachear `favoriteTags` na sessão (invalidar por notificação de prefs do Finder).

**[M76] MEDIUM · DRY · submenu "Copy Path" implementado 4 vezes**
- **Problema:** existe o componente compartilhado `CopyPathMenuContent` (usado por `SidebarItemContextMenu` e `SharedFileItemContextMenu`), mas `SharedBackgroundContextMenu` e `ToolsMenuCommands` re-escrevem os mesmos 4 botões inline.
- **Solução:** todos usam `CopyPathMenuContent`.
- **Esforço:** trivial. **Quando:** agora.

**[M77] MEDIUM · manutenção · cheat sheet de atalhos (`ShortcutsHUDOverlay`) é lista hand-mantida — 4ª fonte de verdade de atalhos**
- **Problema:** `navigationShortcuts`/`fileActionsShortcuts`/`systemShortcuts`/`generalShortcuts` são arrays `(L10n.Key, KeyLabel)` digitados à mão. Somados a: `.keyboardShortcut` nos `*MenuCommands`, keycodes em `KeyboardSelectionNavigator`/`KeyboardZoomController`, e as strings de dica em `SharedFileItemContextMenu`/`SharedBackgroundContextMenu`. **4 definições independentes dos mesmos atalhos**; `KeyLabel.*` usa "⌘ X" e os menus usam "Cmd+X" (2 vocabulários).
- **Impacto:** mudar um atalho num lugar → a cheat sheet e/ou os menus mentem silenciosamente. Evidência concreta de [A3].
- **Solução:** um registro central `Shortcut` (ação → keyCombo → label localizável); menus, monitor e cheat sheet derivam dele.
- **Esforço:** médio/alto. **Quando:** posteriormente (dívida real). **Reforça [A3].**

**[L83] LOW · DRY · `MainContentView.mainBackgroundLayer`/`contentTranslucentBackground` re-escrevem à mão o que `TranslucentBackgroundModifier`/`.translucentBackground(...)` já encapsulam.**

**[L84] LOW · `SharedBackgroundContextMenu:52` — `FileItem.load(url:)` construído na ação do botão "Folder Properties" (`needsOwnerGroup` default → stat+getpwuid+getgrgid). Uma vez por clique; passar `needsOwnerGroup:` conforme o sheet precisa.**

**[L85] LOW · `HoverItemHighlightModifier` — `.scaleEffect(isHovered ? 1.01 : 1.0)` por linha/card no hover (magic `1.01` inline); reflow/blur sutil de 1px.**

**[L79 reforçado]** "`static let` isn't allowed on a generic type" aparece como comentário-justificativa em `ModalHeaderView`, `PaginatedItemsSection` — permitido em Swift moderno (stored static em genérico). Trocar os `static var {N}` por `static let`.

### Lote 23 — `Views/Sidebar/` (SidebarView, SidebarRowView, DirectoryTree*, SmartFolders/Tags sections, PreviewSidebar)

**[M78] MEDIUM · beachball · `SidebarRowView.ejectButton:151-160` — `NSWorkspace.shared.unmountAndEjectDevice(at:)` síncrono no MainActor**
- **Problema:** ejetar volume (pior se rede/lento) roda na ação do `Button`, síncrono; pode travar a UI por segundos. Erro cai em `showError(error.localizedDescription)` (mensagem de sistema, não `WilesError`).
- **Solução:** `Task.detached` para o unmount/eject; hop de volta para refresh/erro.
- **Esforço:** baixo. **Quando:** agora.

**[M6 confirmado]** `SidebarView.sidebarSectionsContent` — a cadeia de gating por seção (`if showRecents`, `if showFavorites && !favoriteItems.isEmpty`, …) é o que `PreferencesStore.hasVisibleSidebarContent` replica. `MainContentView.sidebarPane` usa `hasVisibleSidebarContent` para decidir se mostra a `SidebarView`; a `SidebarView` re-decide por seção. Drift → pane vazio ou seção sumida. Uma fonte só.

**[L86] LOW · DRY · manipulação de tokens de query de busca espalhada** — `SearchFilterService.extractHiddenFlag`/`toggleToken`/`containsToken` + `TagsSectionView.extractTagToken` (mesmo idioma, 4º lugar). Centralizar em `SearchFilterService`.

**[L87] LOW · `SmartFoldersSectionView.smartFolderRenameField:103,105` — dois `.padding(.horizontal, …)` empilhados (10 depois 8); provável typo (um deles seria `.vertical`).**

**[L88] LOW · `SidebarView` — `favoriteItems`/`devices`/`networkAndCloudItems` reconstroem `[SidebarItem]` (cada init faz `standardizedFileURL`) a cada `body`. Bounded pelo nº de favoritos; poderia memoizar.**

**[L89] LOW · `PreviewSidebarView` — larguras `200/250/350` repetidas inline 2×; `SidebarRowView.refreshMissingFavoriteStatus` não re-checa se um favorito some enquanto a sidebar está aberta.**

### Lote 24 — `Views/Header/` + `Views/Footer/` + shared Sidebar chrome

**[M81] MEDIUM · performance · `FooterBarView.iconSizeControl` — `Slider($appState.preferences.iconSize)` persiste no `UserDefaults` a cada frame do drag**
- **Problema:** `iconSize` didSet faz `UserDefaults.set` síncrono; o slider não tem debounce (ao contrário de column-width / sidebar-width que têm). Arrastar o slider = write por frame.
- **Solução:** `iconSize` com persistência debounced (como `expandedTreePaths`), ou `@State` local no slider + commit no fim.
- **Esforço:** baixo. **Quando:** agora.

**[L90] LOW · reforça [M32] · `HeaderBarView.kindFilterButtons` — `"kind:image"/"kind:doc"/"kind:code"` dependem das listas de extensão hardcoded de `SearchFilterService.matchesKindFilter`. `"size:>100m"` (threshold 100MB) hardcoded na view.**

**[L91] LOW · `HeaderBarView.searchEverywhereToggle` chama `refreshCurrentDirectory()` explicitamente; se `searchEverywhere` for alternado por outro caminho (Settings), não há refresh — trigger inconsistente.**

**[S3] SUGGESTION · `RepositionerView` (127 linhas de AppKit defensivo: `static` baseline dict bounded, self-healing, 3 observers de resize) para um nudge cosmético de 6pt das traffic lights — questionar se o custo/manutenção vale o ganho visual.**

### Lote 25 — `Views/Modals/` batch 1 (FileProperties, FolderPicker(+Node), AutoOrganization, Symlink, Feedback, ConnectToServer)

**[A4] ARCHITECTURAL CONCERN · DRY · duas UIs completas de árvore de diretórios**
- **Problema:** `FolderPickerSheet` + `FolderPickerNodeView` (~450 linhas) e `DirectoryTreeSectionView` + `DirectoryTreeNodeView` (sidebar) são duas implementações quase idênticas: node view recursiva, `BoundedFolderNodeCache`, `expandedPaths`, lazy-load de filhos `Task.detached`, `buildRootTree` + timeout GCD + Retry. Diferem só no modelo de seleção (sidebar navega no tap; picker seta `selectedURL`) e no `expandAncestors` do picker.
- **Por que é problema:** ~150 linhas duplicadas incluindo a lógica difícil (cache/lazy/timeout/`/Volumes/` off-actor); correção de bug precisa ser feita 2x.
- **Solução:** um `DirectoryTree` compartilhado parametrizado por (comportamento de tap, binding de seleção, fonte do conjunto expandido). **Alternativa mais radical:** o `FolderPickerSheet` existe só para escolher source/dest de regra de auto-org — trocar por `NSOpenPanel(canChooseDirectories: true)` nativo elimina os ~450 linhas (WILES_RULES "Native-First"). Perde a coluna de favoritos custom, mas o `NSOpenPanel` tem a própria sidebar.
- **Custo/migração:** médio. **Quando:** posteriormente — decidir entre "componente compartilhado" vs "NSOpenPanel".

**[L92] LOW · `AutoOrganizationSheet.canAddRule` compara `standardizedFileURL` (sem symlink-resolve) enquanto `AutoOrganizationRule.init` normaliza com `resolvingSymlinksInPath()` — pode deixar criar uma regra que vira `isSelfReferential` após normalização.**

**[L93] LOW · reforça [C1] · `FeedbackSheetView` envia o texto do usuário como issue no GitHub público via o token hardcoded; a exposição do token significa que qualquer um também **lê** todos os feedbacks/bug reports (podem conter paths/nomes de arquivo dos usuários).**

### Lote 26 — Feature SheetViews + Settings + últimos modais

**[M82] MEDIUM · performance · `BatchRenameSheetView.previews` roda `BatchRenameService.previewNewNames` em `body` a cada tecla**
- **Problema:** `previewList` lê `previews` (computed) que mapeia **todos** os `items` gerando nomes novos; no modo `.regex`, `renamedName` faz `try? NSRegularExpression(pattern:)` **por item**. Batch de 500 itens + modo regex = 500 compilações de regex por caractere digitado.
- **Solução:** computar previews em `.task(id: currentMode)` com debounce; compilar o regex uma vez (fora do loop de itens).
- **Esforço:** baixo. **Quando:** posteriormente.

**[L94] LOW · `DuplicateCleanerSheetView.trashSelected` — loop de `moveToTrash` sem `Task.checkCancellation`; fechar o sheet no meio continua mandando pro Trash (reversível, set pequeno — baixo impacto).**

**[L95] LOW · `SaveSmartFolderSheetView` — `scopePath: currentURL.path` sem tratar o caso de currentURL ser a Recents virtual (`/virtual/recents`) ou uma smart folder ativa.**

**[S4] SUGGESTION · `ImageConverterSheetView` — sem preview do resultado (crop/resize aplicados). Um thumbnail de preview ajudaria; hoje se escolhe preset "às cegas".**

---

# SÍNTESE

## Executive Summary

O Wiles é um projeto **maduro, cuidadoso e acima da média** em disciplina de engenharia. Padrões que normalmente são os primeiros a quebrar aqui estão sólidos: cancelamento de `Task` em loops longos, `withTaskCancellationHandler` encaminhando cancelamento para `Task.detached`, teardown de monitores `NSEvent`/FSEvents/`DispatchSource` em 3 pontos + `deinit`, extração não-destrutiva de arquivos (temp → swap atômico), validação criptográfica completa (SHA-256) antes de deletar duplicatas, caches com `NSCache` bounded por count+cost, `/Volumes/` sempre off-`@MainActor`, acessibilidade completa em quase toda linha de UI, e componentes de interação compartilhados (o que a `WILES_RULES` exige). Os comentários explicam o *porquê* de decisões sutis com precisão rara.

Os problemas encontrados concentram-se em **quatro eixos**:

1. **Um segredo distribuído no binário** — o único achado CRITICAL: um GitHub PAT com escrita em issues hardcoded, extraível de qualquer `.app` shipado.
2. **Performance de render-path** — várias operações O(n) e criações de `ByteCountFormatter`/`stat`/leitura de UserDefaults cross-app rodando por linha/célula/render (busca sem debounce, `statusText`, `isCut`, `colorForTag`, thumbnail `stat`, truncação TextKit).
3. **Sprawl / duplicação** — `PreferencesStore` (god object + ~35 `didSet` idênticos), 2 UIs completas de árvore de diretórios, 4 fontes de verdade de atalhos de teclado, camada de modais partida por lint, debounce reimplementado 4×, "Copy Path" submenu 4×.
4. **Concorrência sem rede de segurança do compilador** — `@unchecked Sendable` em `AppState`/`LocalHttpServerService`/`FileItem`/`SmartFolderService` mais `swiftformat:disable` (proibido pela própria regra) mascarando uma divergência CI/local real.

Nada disso é reescrita. A maior parte é localizada e de baixo/médio esforço. As duas decisões arquiteturais que merecem uma conversa deliberada são o **roteamento de teclado** ([A3]) e as **duas árvores de diretório** ([A4]).

### Notas

| Dimensão | Nota | Racional |
|---|---:|---|
| **Global** | **7.5 / 10** | Base forte, disciplina real, poucos bugs graves; puxada para baixo pelo segredo distribuído e pelo acúmulo de dívida de performance/DRY. |
| **Arquitetura** | **7 / 10** | Facade `AppState` + stores é boa e o isolamento de features funciona. Perde pontos em: god object `PreferencesStore`, `@unchecked Sendable` sem enforcement, roteamento de teclado triplicado, 2 árvores de diretório, camada de modais fragmentada por lint. |
| **Código** | **8 / 10** | Limpo, bem nomeado, bem comentado, funções curtas, decomposição de view correta. Perde por: ~35 `didSet` de persistência copiados, `ByteCountFormatter` implícito recorrente, listas de extensão hardcoded espalhadas, `.localizedDescription` sobre `WilesError`. |
| **Performance** | **6.5 / 10** | Off-actor discipline exemplar para I/O pesado. Mas o render-path tem várias armadilhas O(n)/alocação/`stat` por frame que vão doer em pastas grandes, e a busca não tem debounce. |
| **Concorrência** | **7 / 10** | Padrões corretos (cancelamento, actors onde importa, snapshots antes de async). Risco: `@unchecked Sendable` disperso sem verificação do compilador; `@Observable` de isolamento misto no HTTP server; `swiftformat:disable` proibido em uso. |
| **Segurança** | **4 / 10** | PAT hardcoded distribuído (CRITICAL). Senha de ZIP via argv para senhas com espaço. Sem validação explícita de path traversal na extração (confia em bsdtar/ditto). Boa defesa no HTTP server (traversal, CSP, constant-time). |
| **Produto / UX** | **7.5 / 10** | Empty/loading/error states distintos, confirmações em quase tudo destrutivo, notices de "sem undo", cheat sheet, i18n em 16 línguas. Perde por: "Delete Immediately" sem confirmação, Trash só cobre `~/.Trash`, "cancelar operação" que não cancela, prompt de FDA one-shot. |
| **Manutenibilidade** | **7 / 10** | Comentários de altíssima qualidade e regras `.agents/` levadas a sério. Puxada por: splits forçados por lint (sinal de que os limites estão apertados demais ou os tipos grandes demais), 4 fontes de verdade de atalhos, duplicação de árvore/drop/debounce/copy-path. |

---

## Critical Findings

- **[C1]** GitHub PAT (escrita em issues) hardcoded em `CrashReportingConstants.swift`, distribuído em todo binário. Expõe dados de usuários nos crash/feedback reports e permite vandalismo do issue tracker. **Corrigir a direção com o usuário agora** (relay serverless vs. redigir+rotacionar). Ver Lote 14.

## High Priority Findings

| ID | Título | Lote |
|---|---|---|

## Architecture Concerns

| ID | Título | Recomendação | Lote |
|---|---|---|---|
| **[A1]** | `AppState: @unchecked Sendable` — segurança depende de convenção não-verificada em `Task.detached` | Parar de capturar `self`; capturar só valores `Sendable`; ou `actor` para o trabalho detached | 1 |
| **[A2]** | `PreferencesStore` god object (~10 concerns, já partido por lint) | Separar em `ViewPreferences`/`SidebarPreferences`/`SearchPreferences`/`AppearancePreferences` + `FavoritesStore`; incremental | 2 |
| **[A3]** | Roteamento de teclado em 3 mecanismos + 4 fontes de verdade de atalhos (cheat sheet mente se um mudar) | Um registro central `Shortcut` (ação → keyCombo → label); menus/monitor/cheat sheet derivam | 19, 22 |
| **[A4]** | Duas UIs completas de árvore de diretórios (~150 linhas duplicadas, incl. lógica difícil) | Componente `DirectoryTree` compartilhado, OU trocar `FolderPickerSheet` por `NSOpenPanel` nativo | 25 |
| **[M65]** | `LocalHttpServerService` — `@Observable` de isolamento misto (props mutadas de `queue` de background) | Separar superfície observável `@MainActor` do estado interno do servidor | 17 |

## Bugs Discovered

| ID | Sev | Bug | Lote |
|---|---|---|---|

## Performance Findings

| ID | Sev | Achado | Lote |
|---|---|---|---|
| [M31] | MED | `SearchFilterService` — N+1 de `resourceValues` por token de filtro | 8 |
| [M30] | MED | Busca recursiva reordena+reenvia lista inteira a cada 40 matches (~O(n²)) | 7 |
| [M40] | MED | `ThumbnailService.cachedThumbnail`/`ImageThumbnailView.init` fazem `stat` por célula de imagem, de `body`/init | 10, 21 |
| [M46] | MED | Truncação TextKit (`FinderStyleTruncationService`) chamada de `body`, síncrona, no cache-miss | 12 |
| [M50] | MED | `colorForTag` → lê `com.apple.finder` UserDefaults + parse **por tag, por linha, por render** | 22 |
| [M67]/[M73] | MED | Mudar `sortOption`/`sortAscending` re-lê o diretório do disco (deveria re-ordenar em memória); clique em header dispara refresh **duplo** | 18, 19 |
| [M81] | MED | Slider de tamanho de ícone persiste no `UserDefaults` a cada frame do drag (sem debounce) | 24 |
| [M82] | MED | `BatchRenameSheetView` roda `previewNewNames` (compila regex por item) em `body` a cada tecla | 26 |
| [M28-perf]/[M74] | MED | `OpenWithService.availableApplications` (LaunchServices + N `Bundle`) roda em `body` do menu de contexto | 20 |

## Swift / SwiftUI Findings

- **[M21]** `swiftformat:disable redundantSelf` (8×) — **proibido** pela regra "Never Resolve a Lint/Format/Config Conflict Unilaterally"; mascara divergência CI vs. local que precisa ser escalada. (Lote 5)
- **[M71]** Retain cycle frágil `Coordinator.parent` ↔ `WindowUIState.terminalViewCache` — quebrado só manualmente em `tearDown()`. (Lote 19)
- **[M72]** `CursorModifier` — `NSCursor.push()/pop()` desbalanceia (remoção durante hover / double-enter). `AboutSheet` mostra o padrão certo. (Lote 19)
- **[L79]** `"static let não é permitido em tipo genérico"` (permitido no Swift moderno) em 2 arquivos. (Lotes 21, 22)
- **[L45]** Tipo-namespace de serviço varia sem critério (`enum`/`struct`/`final class`/`actor`, todos só-estáticos). (Lote 12)
- **[M15]** ~6 idiomas de "operação em background" em `AppState+Operations` (`createNewFileAndRename` roda I/O síncrono no MainActor). (Lote 4)

## UI / UX Findings

- **[M14]** Progresso rotulado "bytes" mas alimentado com contagem de itens → barra inútil ao copiar/deletar um arquivo gigante (Lote 4).
- **[M24]** Trash size / "Empty Trash" só cobrem `~/.Trash`, ignoram `.Trashes` de volumes externos → "esvaziei mas o disco continua cheio" (Lote 5).
- **[M44]** Prompt de Full Disk Access é one-shot no launch; quem clica "Not Now" nunca mais é perguntado (Lote 11).
- **[M36]** Colisão em undo/redo vira erro sem recurso (sem prompt Replace/Keep Both) (Lote 9).
- **[M56]/[M28]** Mensagens de falha parcial e erros de `WilesError` chegam em inglês para usuários não-ingleses (Lotes 15, 26).
- **[L30]** Content search silenciosamente no-op para query < 3 chars; regex inválida = zero resultados sem aviso (Lote 8).
- **[L74]** `InlineRenameField` não sanitiza `/`/`:` no nome (erro cru vs. o swap que o Finder faz) (Lote 20).
- **[L73]** Dica de atalho `"#10"` (placeholder/typo) visível no menu de contexto para "Copy Content" (Lote 20).

## Product / Future Evolution

- **[S1]** `AutoOrganizationRule` — condição única (`extensionEquals`/`nameContains`/`namePrefix`). Usuários vão querer OR de extensões e multi-condição. Preparar `[Condition]` + `matchMode` quando houver demanda.
- **[M66]** HTTP share sem `Range`/`206` — download interrompido recomeça do zero, sem seek de vídeo, tudo baixa em vez de abrir inline. Esperado numa feature de compartilhamento.
- **[M24]** Trash multi-volume (produto).
- **[L64]** HTTP share: deixar claro no sheet que a senha é "acesso casual, não sniffer" (é HTTP puro na LAN).
- **[S3]** `RepositionerView` — 127 linhas de AppKit defensivo para um nudge de 6pt das traffic lights; questionar o custo/benefício.
- **[S4]** `ImageConverterSheetView` sem preview do crop/resize.

## DRY / KISS / SOLID Findings (consolidado)

| Duplicação | Onde | ID |
|---|---|---|
| Lógica de debounce (`DispatchWorkItem` + `asyncAfter` + `?.cancel()`) | `FolderWatcher`, `PreferencesStore` (2×), `FileSystemStore`, `PathBarView`, `SidebarView` | M33 |
| Duas UIs de árvore de diretórios | `DirectoryTree*` (sidebar) vs `FolderPicker*` | A4 |
| Duas impls de "move batch com colisão sticky" | `AppState+Favorites` vs `AppState+Operations` | M23 |
| Submenu "Copy Path" | `CopyPathMenuContent` (compartilhado) vs `SharedBackgroundContextMenu` + `ToolsMenuCommands` (inline) | M76 |
| 4 fontes de verdade de atalhos | `*MenuCommands` / `KeyboardSelectionNavigator` / dicas de menu / `ShortcutsHUDOverlay` | A3, M77 |
| Lógica "is hidden" | `FileItem`+`FileSystemService` | L26 |
| Listas de extensão hardcoded (image/doc/code/archive/text) | `SearchFilterService`, `SyntaxHighlighterService`, `SharedFileItemContextMenu`, `ThumbnailService`(via UTType — o jeito certo) | M32, M48 |
| `ByteCountFormatter` implícito (não-cacheado) | `FileItem`, `AppState+Text`, `DiskUsageItem`, `TrashState`, `DuplicateCleanerSheetView`, tooltip | M69 |
| 6ª reimplementação de nome-único | `ImageConverterService.uniqueDestinationURL` | M57 |
| Camada de modais partida por lint (`function_body_length`) | `WilesModalSheets` + `...Secondary` + `...Alerts` | M70 |

## Overengineering / Simplification Opportunities

- **[M70]** Camada de modais: 3 arquivos + cadeia de 19 `||` (`isAnyModalPresented`) → um `enum ActiveModal: Identifiable` + **um** `.sheet(item:)`. Colapsa tudo.
- **[A4]** `FolderPickerSheet` + `FolderPickerNodeView` (~450 linhas) possivelmente substituíveis por `NSOpenPanel` nativo (WILES_NATIVE-FIRST).
- **[L25]** `FileSystemService.compressToZIP`/`extractZIP` — forwarders mortos para `ArchiveService`. Deletar.
- **[O/M18]** `DirectoryLoadResult` — struct que envelopa um único `[FileItem]` sem comportamento; virar `typealias` ou sumir.
- **[M22]** "Preview e disk-usage sidebar são mutuamente exclusivos" enforçado em 4 `didSet` → um `enum TrailingInspector`.
- **Nota (contra-corrente):** o projeto **não** sofre de excesso de abstração/protocolos. Os protocolos existentes (`WorkspaceOpening`, `*ServiceProtocol`) têm justificativa de DI real. A simplificação aqui é **anti-sprawl**, não anti-abstração.

---

## Suggested New Engineering Rules

**REGRA 1 — Toda persistência de preferência passa por um único mecanismo.**
- Problema que evita: esquecer o `didSet` numa nova pref (regressão de "Complete State Persistence") e os 4 estilos de persistência hoje coexistindo.
- Exemplos: `PreferencesStore` (~35 didSets), `iconSize` sem debounce, `listColumnStates` com JSON, `expandedTreePaths` com GCD.
- Vira: guideline + `@Persisted`/`Persisted<T>` + lint (ver Lint LR1).

**REGRA 2 — `struct`/`enum` `Identifiable`/`Hashable` de dado derivado do disco: identidade DEVE vir do path/URL, nunca de `UUID()` novo.**
- Evita: churn de `ForEach`/`Set` e perda de seleção a cada rescan.
- Exemplos: `NetworkShare` (bug), `SidebarItem` (fez certo, de propósito).
- Vira: code-review rule + lint custom (LR3).

**REGRA 3 — Nenhuma credencial de escrita embarcada no `.app`.**
- Evita: [C1]. Segredos de telemetria/report ficam atrás de um relay, não no cliente.
- Vira: guideline + o `no_hardcoded_secrets` do SwiftLint **sem** `disable` permitido.

**REGRA 4 — Atalho de teclado tem uma única definição; menus, monitor e cheat sheet derivam dela.**
- Evita: a cheat sheet e as dicas de menu divergirem do comportamento real ([A3]/[M77]).

**REGRA 5 — `swiftformat:disable`/`swiftlint:disable` são proibidos (já é regra) — e quando o CI e o local divergem, isso é um item de backlog, não um `disable`.**
- Exemplos: os 8 `swiftformat:disable redundantSelf`. Alinhar a versão do swiftformat no CI/local.

**REGRA 6 — Todo inicializador ou default de stored property que toca disco/rede deve ter o nome gritando isso (`load`, `fetch`, `async`) — nunca um `init()` "inocente".**
- Evita: [M41] (`AutoOrganizationService.shared`). (`FileItem`/`PreferencesStore` já resolvidos.)
- Generaliza a memória "SwiftUI init() side effects".

**REGRA 7 — Erro que chega a um alerta do usuário passa por `AppState.showError(_ error:)` / `WilesError.localizedMessage(lang:)` — nunca `.localizedDescription`.**
- Evita: [M28] (inglês para usuário não-inglês). Lint LR2.

**REGRA 8 — Toda operação de arquivo em lote (`for url in urls`) checa `Task.checkCancellation()` no topo da iteração.**
- Já é praticada na maioria (`FileShredder`, `DuplicateDetection`, `PDFMerge`) mas falta em `BatchRenameService`, `DuplicateCleanerSheetView.trashSelected`, `moveItemsResolvingCollisions`.

---

## Suggested Lint Rules

| ID | Regra | Detecta | Abordagem | Falso-positivo | Benefício |
|---|---|---|---|---|---|
| **LR1** | Stored `var` num store `@Observable` cujo nome bate com um `DefaultsKey` mas sem `didSet` que persista | esquecer persistência de nova pref | SwiftLint custom_rule (regex sobre `var X` + ausência de `didSet.*DefaultsKey.X` no arquivo) OU migrar tudo p/ `@Persisted` e banir `var` "solto" no `PreferencesStore` | médio (props computed/transientes) — allowlist | fecha a regressão de "Complete State Persistence" mecanicamente |
| **LR2** | `.localizedDescription` como argumento de `showError(` / `operationFailed(reason:` | [M28] — inglês vazando | regex: `showError\([^)]*\.localizedDescription` | baixo | mensagens de erro sempre no idioma do app |
| **LR3** | `let id = UUID()` numa `struct` que também conforma `Identifiable`+(`Hashable`/`Equatable` sintetizado) | [Regra 2] — churn de identidade | SwiftLint AST custom rule, ou regex `let id = UUID\(\)` + grep de `Identifiable` no arquivo | médio (ids genuinamente aleatórios e persistidos — como `SmartFolder`) — allowlist | previne bug de perda de seleção/re-render |
| **LR5** | `String(fileURLWithPath:` / `FileItem(url:` / `resolvingSymlinksInPath()` dentro de um `var body`/computed de `View` | I/O de disco em render-path (DEV_RULES #19) | regex por arquivo `Views/` + heurística de bloco `body` | médio (precisa de contexto de bloco) | pega beachballs latentes |
| **LR6** | `NSCursor.push()` sem `NSCursor.pop()` correspondente no mesmo tipo, ou sem `onDisappear` | [M72] — cursor preso | regex de pareamento por arquivo | baixo | evita cursor "grudado" |
| **LR7** | `swiftformat:disable` / `swiftlint:disable` (qualquer) | [M21]/[Regra 5] — já proibido, tornar mecânico | regex | zero (é um `disable`, sempre suspeito) | torna a regra existente executável no CI |
| **LR8** | Literal de string com `Cmd+`/`⌘`/`Shift+` fora do registro central de atalhos | [A3] — dica de atalho hardcoded | regex `"[^"]*(Cmd\+|⌘|Shift\+)` em `Views/`, excluindo o arquivo do registro | médio | força o "single source of truth" de atalhos |

Regex simples e realmente úteis para começar já: **LR2**, **LR4**, **LR7** (baixíssimo falso-positivo, alto valor).
