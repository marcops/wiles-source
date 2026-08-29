# Architecture & Code Review

Formato de cada achado:
`[ID] SEVERIDADE · Categoria · arquivo:símbolo` seguido de
**Problema / Por que / Impacto / Solução / Esforço / Quando**.

IDs: `C#` critical, `H#` high, `M#` medium, `L#` low, `S#` suggestion,
`A#` architectural concern, `O#` overengineering, `B#` bug, `P#` performance,
`U#` product/UX.


### Lote 8 — `SearchFilterService`, `DirectoryCacheService`, `FolderWatcher`

**DirectoryCacheService.swift — praticamente sem achado.** `NSCache` com `countLimit`+`totalCostLimit`, TTL via `isStale`, `@unchecked Sendable` legítimo. LOW: caminhos de mutação (paste/delete/move) não chamam `invalidate`, então há ~1 frame de conteúdo stale possível ao renavegar em <30s (o load async reconcilia).

### Lote 11 — `NetworkDiscovery/Server`, `OpenWith`, `PDFMerge`, `POSIXPermissions`, `FilePermissions`, `Symlink*`, `PermissionService`

### Lote 13 — serviços restantes (`SystemAppearance/Tags`, `FileTagging`, `CopyPath`, `Bundle+`, `HTMLEscaping`, `L10n+Lookup`, `AppLanguage`, `NewFileTemplate`, `TemplateRendering`, `FileShredder`)

**[S2] SUGGESTION · `AppLanguage.allCases` vs `Resources/*.lproj` — adicionar teste (quando testes forem escritos) que afirma que o enum e as pastas `.lproj` no disco batem exatamente, para pegar drift (relacionado ao incidente do `shortcutsAllTab` cru que já foi pro app).**


**[L53] LOW · consistência · `AsyncDelayTokens.swift` mistura `TimeInterval`, `UInt64` (nanos crus `3_000_000_000`) e `Duration` para a mesma categoria de valor.** Padronizar em `Duration` (`.seconds`/`.milliseconds`).

**[L55] LOW · consistência · `EditMenuCommands` — cut/copy têm `.disabled(seleção vazia)`, paste não tem `.disabled` nenhum.**


**[M64] MEDIUM · complexidade · `SmartFolderService.runQuery` — juggling manual de `NSMetadataQuery` + `NotificationCenter` com 3 níveis de `Task { @MainActor [weak self] }` aninhados e remoção de observer em 3 pontos**
- **Problema:** difícil de auditar; observer removido antes de adicionar, dentro do Task, e implicitamente ao parar. `swiftformat:disable redundantSelf` (ver [M21]).
- **Solução:** encapsular numa pequena classe `SpotlightQuery` com `async` API (`func run() async -> [URL]`) que gerencia observer+stop internamente com `withCheckedContinuation` + `defer` de cleanup garantido.
- **Esforço:** médio. **Quando:** posteriormente.

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

### Lote 18 — `Views/Content/` núcleo (`MainContentView`, `FileCollectionContainerView`, `FileGridView`, `FileListView`, `FileGridCardItemView`)

**[L68] LOW · dois handlers para a tecla Delete · `MainContentView.keyboardShortcutsHandler` tem `.onDeleteCommand { deleteSelected }` e `FileMenuCommands` tem `Button(moveToTrash).keyboardShortcut(.delete)`.** Coordenado via `isAnyModalPresented`/`GlobalKeyMonitor`, mas é frágil — consolidar num só ponto.

**[L69] LOW · perf menor · `FileGridView.renameFieldOverlay`/`revealFieldOverlay` fazem `items.first(where:)` (O(n)) em `body`; `revealFieldOverlay` chama `FinderStyleTruncationService.wrappedLines` em `body` (reforça [M46]).**

### Lote 19 — `Views/Content/` teclado + wiring de modais

**[A3] ARCHITECTURAL CONCERN · roteamento de teclado espalhado por 3 mecanismos**
- **Problema:** atalhos/teclas são tratados em (1) `GlobalKeyMonitor` (monitor `NSEvent` local) → `KeyboardSelectionNavigator`/`KeyboardZoomController`, (2) `MainContentView.keyboardShortcutsHandler` (Buttons SwiftUI ocultos + `.onDeleteCommand`), (3) os 7 `*MenuCommands` (`.keyboardShortcut`). Precedência: o monitor roda primeiro e engole (`return nil`) o que trata; os outros só veem o que sobra.
- **Por que é problema:** difícil raciocinar sobre qual caminho trata cada tecla em cada estado (foco em text field, modal aberto, `navigationMode`); Delete tem 3 handlers; a "cheat sheet" de atalhos pode divergir do real; adicionar/mudar um atalho exige checar 3 lugares.
- **Impacto:** bugs de atalho dependentes de foco/estado; manutenção cara.
- **Solução:** um único roteador de comandos (uma tabela `keyCode+modifiers → Command`), consultado pelo monitor; os menus expõem os mesmos `Command`s. `MainContentView` para de ter Buttons ocultos.
- **Esforço:** médio/alto. **Quando:** posteriormente (dívida arquitetural real, não urgente).

### Lote 20 — `Views/Components/` interação (`FileItemInteractionsModifier`, `SharedFileItemContextMenu`, `InlineRenameField`, `SelectionRectangleOverlay`, `MultiFileDragView`, `SelectionAwareNameText`, `ClickOutsideDetector`)

**[M75] MEDIUM · DRY · dicas de atalho hardcoded no `SharedFileItemContextMenu` duplicam as definições reais de `.keyboardShortcut`**
- **Problema:** `"Space"`, `"Cmd+X"`, `"Cmd+C"`, `"Cmd+V"`, `"Opt+Cmd+Del"`, `"Cmd+I"`, `"F2"`/`"Return"` são strings fixas no menu; os atalhos reais vivem em `*MenuCommands`/`GlobalKeyMonitor`. Divergem se um atalho mudar.
- **Solução:** derivar de um registro central de atalhos (liga-se a [A3]).
- **Esforço:** médio. **Quando:** posteriormente.

**[L73] LOW · UX / bug de texto · `SharedFileItemContextMenu.contentActionsSection:83` — dica de atalho `"#10"` para "Copy Content"** — parece placeholder/typo; vira "(#10)" visível ao usuário. Não há atalho real; passar `shortcut: ""` ou remover a dica.

**[L74] LOW · UX · `InlineRenameField` / `performRename` não valida nome de arquivo** — digitar `a/b` ou `:` cria/erra em vez de sanitizar como o Finder (`:`↔`/` swap, rejeitar `/`). Erro cru para o usuário.

**[L75] LOW · perf/complexidade · `FileItemInteractionsModifier` empilha 7 camadas de gesto/interação por linha (2 taps + drag + `RightClickDetector` + `MultiFileDragView` + `.contextMenu` + `.springLoadedFolder`) × N células visíveis.** É o componente compartilhado que as regras exigem (DRY ok), mas a densidade de recognizers por célula é alta. Monitorar se vira gargalo em grids grandes.

**[L76 parcial] `SharedFileItemContextMenu.imageFileExtensions` hardcoded — resta em [M48] (ShareLink rotulado corrigido p/ `.share`; "Merge into PDF" agora exige ≥2 arquivos).**

### Lote 21 — `Views/Components/` batch 3 (async/pagination/scroll/detectors/operations popover)

**[M40 reforçado]** `ImageThumbnailView.init:14` — chama `ThumbnailService.shared.cachedThumbnail(for:size:)` como `@State(initialValue:)`, e `cachedThumbnail`→`cacheKey` faz um `stat` (`resourceValues([.contentModificationDateKey])`). Ou seja: **um `stat` síncrono no init de cada célula de imagem**, refeito a cada create/destroy de célula no scroll do `LazyVGrid`. Confirma [M40].

**[L77] LOW · UX · `ResetPaginationAndPrefetchThumbnails.thumbnailPrefetchItemThreshold = 500` — só faz prefetch de thumbnails em pastas com >500 itens.** Pasta com 400 imagens não recebe prefetch → thumbs aparecem devagar no scroll. Lógica meio invertida (prefetch beneficia mais pastas de imagem menores).

**[L80] LOW · perf menor · `PaginatedItemsSection.visibleItems` faz `Array(items.prefix(visibleLimit))` a cada `body` quando paginando (>500 itens).**

**[L81] LOW · `FileItemIconView`/`ThumbnailService.supportsThumbnail` — `UTType(filenameExtension:)` + 5 `conforms(to:)` por ícone por render (reforça [M48]; precomputar no `FileItem`).**

### Lote 22 — `Views/Components/` shared (menus, chrome, KeyLabel, ShortcutsHUD, Tags, Modal scaffold, Theme)

**[M77] MEDIUM · manutenção · cheat sheet de atalhos (`ShortcutsHUDOverlay`) é lista hand-mantida — 4ª fonte de verdade de atalhos**
- **Problema:** `navigationShortcuts`/`fileActionsShortcuts`/`systemShortcuts`/`generalShortcuts` são arrays `(L10n.Key, KeyLabel)` digitados à mão. Somados a: `.keyboardShortcut` nos `*MenuCommands`, keycodes em `KeyboardSelectionNavigator`/`KeyboardZoomController`, e as strings de dica em `SharedFileItemContextMenu`/`SharedBackgroundContextMenu`. **4 definições independentes dos mesmos atalhos**; `KeyLabel.*` usa "⌘ X" e os menus usam "Cmd+X" (2 vocabulários).
- **Impacto:** mudar um atalho num lugar → a cheat sheet e/ou os menus mentem silenciosamente. Evidência concreta de [A3].
- **Solução:** um registro central `Shortcut` (ação → keyCombo → label localizável); menus, monitor e cheat sheet derivam dele.
- **Esforço:** médio/alto. **Quando:** posteriormente (dívida real). **Reforça [A3].**


**[L84] — sem ação: o comentário no código já explica que o sheet de Properties mostra Owner/Group, então o `needsOwnerGroup` default está correto; e é uma vez por clique.**

**[L79 reforçado]** "`static let` isn't allowed on a generic type" aparece como comentário-justificativa em `ModalHeaderView`, `PaginatedItemsSection` — permitido em Swift moderno (stored static em genérico). Trocar os `static var {N}` por `static let`.

### Lote 23 — `Views/Sidebar/` (SidebarView, SidebarRowView, DirectoryTree*, SmartFolders/Tags sections, PreviewSidebar)

**[L86] LOW · DRY · manipulação de tokens de query de busca espalhada** — `SearchFilterService.extractHiddenFlag`/`toggleToken`/`containsToken` + `TagsSectionView.extractTagToken` (mesmo idioma, 4º lugar). Centralizar em `SearchFilterService`.

**[L87] LOW · `SmartFoldersSectionView.smartFolderRenameField:103,105` — dois `.padding(.horizontal, …)` empilhados (10 depois 8); provável typo (um deles seria `.vertical`).**

**[L88] LOW · `SidebarView` — `favoriteItems`/`devices`/`networkAndCloudItems` reconstroem `[SidebarItem]` (cada init faz `standardizedFileURL`) a cada `body`. Bounded pelo nº de favoritos; poderia memoizar.**

**[L89 resto] `SidebarRowView.refreshMissingFavoriteStatus` não re-checa se um favorito some enquanto a sidebar está aberta (larguras do `PreviewSidebarView` já nomeadas).**

### Lote 24 — `Views/Header/` + `Views/Footer/` + shared Sidebar chrome

**[S3] SUGGESTION · `RepositionerView` (127 linhas de AppKit defensivo: `static` baseline dict bounded, self-healing, 3 observers de resize) para um nudge cosmético de 6pt das traffic lights — questionar se o custo/manutenção vale o ganho visual.**

### Lote 25 — `Views/Modals/` batch 1 (FileProperties, FolderPicker(+Node), AutoOrganization, Symlink, Feedback, ConnectToServer)

**[A4] ARCHITECTURAL CONCERN · DRY · duas UIs completas de árvore de diretórios**
- **Problema:** `FolderPickerSheet` + `FolderPickerNodeView` (~450 linhas) e `DirectoryTreeSectionView` + `DirectoryTreeNodeView` (sidebar) são duas implementações quase idênticas: node view recursiva, `BoundedFolderNodeCache`, `expandedPaths`, lazy-load de filhos `Task.detached`, `buildRootTree` + timeout GCD + Retry. Diferem só no modelo de seleção (sidebar navega no tap; picker seta `selectedURL`) e no `expandAncestors` do picker.
- **Por que é problema:** ~150 linhas duplicadas incluindo a lógica difícil (cache/lazy/timeout/`/Volumes/` off-actor); correção de bug precisa ser feita 2x.
- **Solução:** um `DirectoryTree` compartilhado parametrizado por (comportamento de tap, binding de seleção, fonte do conjunto expandido). **Alternativa mais radical:** o `FolderPickerSheet` existe só para escolher source/dest de regra de auto-org — trocar por `NSOpenPanel(canChooseDirectories: true)` nativo elimina os ~450 linhas (WILES_RULES "Native-First"). Perde a coluna de favoritos custom, mas o `NSOpenPanel` tem a própria sidebar.
- **Custo/migração:** médio. **Quando:** posteriormente — decidir entre "componente compartilhado" vs "NSOpenPanel".


### Lote 26 — Feature SheetViews + Settings + últimos modais

**[L95] LOW · `SaveSmartFolderSheetView` — `scopePath: currentURL.path` sem tratar o caso de currentURL ser a Recents virtual (`/virtual/recents`) ou uma smart folder ativa.**

**[S4] SUGGESTION · `ImageConverterSheetView` — sem preview do resultado (crop/resize aplicados). Um thumbnail de preview ajudaria; hoje se escolhe preset "às cegas".**
