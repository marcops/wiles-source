# Architecture & Code Review

## Findings by ID

---

### [AM-101] `runDetachedFileOperation` promete off-main **estrutural** mas não entrega para operações `@MainActor` (undo/redo)
- ROI: 1.01
- ARCHITECTURAL CONCERN / OVERENGINEERING — Swift Concurrency
- Arquivo: `Models/AppState/AppState+Operations.swift` (`runDetachedFileOperation`), `Services/UndoRedoService.swift` (`@MainActor`)
- Evidência: HIGH CONFIDENCE (o comportamento é consequência clara do fluxo; já parcialmente documentado em `SWIFT_LANG_RULES.md` R3).
- Problema: o helper embrulha `operation` em `Task.detached { try await operation() }` + `withTaskCancellationHandler`, sugerindo que o trabalho roda fora do main actor por construção. Mas `undoLastAction()`/`redoLastAction()` passam `operation: { try await service.undo() }` onde `service` é `UndoRedoService` **`@MainActor`**. O `Task.detached` inicia fora do main, dá `await` imediato e volta ao `@MainActor` para rodar `undo()`. Só não vira beachball porque as folhas (`FileSystemService.moveItem/renameItem`) se auto-detacham. O `Task.detached` + cancellation handler não compram nada estrutural nesse caminho — compram complexidade (um `Task` extra, um handler de cancelamento que `undo()` nunca checa via `Task.checkCancellation()`).
- Por que é um problema: cria falsa sensação de segurança. Um caller futuro que passe uma `operation` `@MainActor`-isolada fazendo trabalho pesado (ex.: um novo undo que enumere diretório no próprio corpo) roda no main sem erro de compilação. É a mesma armadilha do R3 um nível acima.
- Impacto: nenhum bug hoje; risco latente de regressão silenciosa de performance.
- Solução: (a) documentar no doc-comment de `runDetachedFileOperation` que `operation` DEVE ser `nonisolated`/`Sendable` e que o wrapper não protege trabalho `@MainActor`-isolado (mesma frase do R3); (b) para undo/redo, largar o `Task.detached` e chamar `service.undo()` direto num `Task { @MainActor }` — o helper genérico não agrega valor aí. Menos linhas, mesma corretude.
- Complexidade da correção: baixa (doc + simplificar 2 call sites).
- Impacto:20 / Redução de risco:25 / Manut.:45 / Perf.:10 / Simplicidade:55 / Esforço:35 / Risco mudança:25 → VALUE≈29.75 / COST≈32.5 / **ROI 0.92**

> (ROI recalculado: 0.92 — ver filtro NOT WORTH; mantido na lista principal por ser ARCHITECTURAL CONCERN, não descartável por ROI.)

---

### [LL-118] Invalidação de cache de diretório inconsistente entre caminhos de mutação
- ROI: 1.18
- LOW / BUG (flash de frame stale) — consistência de APIs internas
- Arquivo: `Models/AppState/AppState+Operations.swift` (`handleDrop`)
- Evidência: HIGH CONFIDENCE (comparação direta com `executePaste`/`performDeleteSelected`/`pasteClipboardContentAsFile`, todos usam `invalidateCurrentDirectoryCacheAndRefresh()`).
- Problema: `handleDrop` termina com `refreshCurrentDirectory()` puro. Se o `targetFolder` do drop for a pasta atual (drop no fundo da janela), o listing em cache de `currentURL` ficou stale e o fast-path de cache em `refreshCurrentDirectory` pinta um frame antigo (sem os itens recém-movidos) antes da carga real reconciliar.
- Por que é um problema: os outros 3 caminhos de mutação in-place já tratam isso; `handleDrop` diverge sem razão aparente. Inconsistência = bug esperando o caso certo.
- Impacto: flicker visual momentâneo num drop sobre a própria pasta; sem perda de dados.
- Solução: trocar por `invalidateCurrentDirectoryCacheAndRefresh()` quando `targetFolder == navigation.currentURL` (ou incondicionalmente, já que `remapRelocatedState` também invalida os pais e o custo é 1 dict remove).
- Complexidade: trivial (1 linha).
- Impacto:25 / Redução de risco:15 / Manut.:35 / Perf.:5 / Simplicidade:20 / Esforço:8 / Risco:10 → VALUE≈20.0 / COST≈8.6 → **ROI 2.33**

> Correção do ID: **[LL-233]** (Low/Low, ROI 2.33).

---

### [ML-090] `NavigationStore.recentOpenedURLs` mistura URLs padronizadas e não-padronizadas
- ROI: 0.90
- MEDIUM / BUG (comparação silenciosa falha) — tipos/normalização de URL
- Arquivo: `Models/AppState/Stores/NavigationStore.swift` (`init` restore vs `addToRecents`)
- Evidência: MEDIUM CONFIDENCE (depende de um caminho de comparação `==`/`contains` específico sobre a lista).
- Problema: no `init`, recents restaurados de `UserDefaults` viram `URL(fileURLWithPath: path)` **sem** `.standardizedFileURL`. Em `addToRecents`, as entradas são gravadas como `std` (padronizadas). A mesma coleção passa a conter as duas formas. `addToRecents` deduplica comparando `.standardizedFileURL` (ok), mas qualquer consumidor que faça `recentOpenedURLs.contains(someURL)` ou `== someURL` cru (ex.: destacar a linha "Recents" ativa na sidebar, `FileItem` derivado por `==`) pode não casar após um restart até o path ser revisitado.
- Por que é um problema: viola a regra "Strict File URL Normalization" (`SWIFT_LANG_RULES.md`) — dois lados de origens diferentes devem ser resolvidos a `.standardizedFileURL` antes de `==`. Aqui uma origem é `UserDefaults` persistido e a outra é código in-app.
- Impacto: inconsistência de estado de UI (linha Recents não destaca; item aparece duplicado até revisita). Sem perda de dados.
- Solução: padronizar no restore: `URL(fileURLWithPath: path).standardizedFileURL`. Uma linha, alinha com `lastOpenedFolder` que já faz isso.
- Complexidade: trivial.
- Impacto:30 / Redução de risco:20 / Manut.:35 / Perf.:0 / Simplicidade:15 / Esforço:6 / Risco:8 → VALUE≈22.25 / COST≈5.8 → **ROI 3.84**

> Correção do ID: **[ML-384]**.

---

### [LL-100] `applyLoadedItems` descarta refresh concluído durante rename sem limpar `isLoading`
- ROI: 1.00
- LOW / BUG (spinner preso) — lifecycle
- Arquivo: `Models/AppState/AppState+Navigation.swift` (`applyLoadedItems`), `Models/AppState/Stores/FileSystemStore.swift`
- Evidência: MEDIUM CONFIDENCE (requer condição específica: refresh user-initiated em voo + `renamingURL` setado antes da conclusão).
- Problema: `guard fileSystem.renamingURL == nil else { return }` sai cedo e **não** faz `fileSystem.isLoading = false`. Se `refreshCurrentDirectory(isUserInitiated: true)` ligou o spinner (`items.isEmpty`) e um rename começou antes da carga async terminar, o resultado é jogado fora e `isLoading` fica `true` até o próximo refresh completar fora de rename.
- Por que é um problema: estado de loading não corresponde ao resultado real da operação (invariante "estado final == resultado").
- Impacto: spinner preso numa janela de tempo estreita; auto-resolve no próximo FSEvents/refresh.
- Solução: no early-return por `renamingURL`, ainda setar `fileSystem.isLoading = false` (a carga terminou; só não aplicamos os itens).
- Complexidade: trivial.
- Impacto:20 / Redução de risco:15 / Manut.:20 / Perf.:0 / Simplicidade:10 / Esforço:5 / Risco:8 → VALUE≈14.75 / COST≈8.9 → **ROI 1.66**

> Correção do ID: **[LL-166]**.

---

### [SL-070] `BackgroundOperationsService.shared` guarda estado de sessão e progride em todas as janelas
- ROI: 0.70
- SUGGESTION / ARCHITECTURAL CONCERN — window-scoped state
- Arquivo: `Services/BackgroundOperationsService.swift`
- Evidência: HIGH CONFIDENCE.
- Problema: é `.shared` e mantém `activeTasks` + `cancellationHandlers` (estado de sessão mutável). Progresso de uma cópia iniciada na janela A aparece no rodapé/popover da janela B. A regra "Shared service lifecycle ownership — BLOCKING" mira browsers/servers/scans com `start()/stop()` dirigido por View; este serviço é mais um "centro de notificações" sem lifecycle por-View, então não é violação literal — mas `activeTasks` ainda é "o que ALGUMA janela está fazendo agora" num singleton.
- Por que é um problema (menor): se o usuário associa o popover de operações à janela corrente, ver a operação de outra janela confunde; e um `cancellationHandlers[id]` capturando o `Task` de uma janela que fechou fica vivo até `completeTask`.
- Impacto: baixo; hoje funciona.
- Solução (se algum dia incomodar): instância por-`AppState` como já foi feito para `SmartFolderService`/`LocalHttpServerService`/`NetworkDiscoveryService`; ou aceitar explicitamente como canal app-wide e documentar. **Não** mudar agora sem demanda concreta (YAGNI).
- Complexidade: média.
- Impacto:15 / Redução de risco:15 / Manut.:20 / Perf.:0 / Simplicidade:5 / Esforço:45 / Risco:35 → VALUE≈12.0 / COST≈42 → **ROI 0.29**

> **NOT WORTH** — ver seção NOT WORTH (não envolve crash/perda/vazamento; ROI 0.29).

---

### [MH-142] Auto-organização pode nunca mover um arquivo que estava sendo escrito in-place durante o único scan
- ROI: 1.42
- MEDIUM / BUG — eventos de alta frequência / idempotência / lifecycle
- Arquivo: `Services/AutoOrganizationService.swift` (`processFolder` → `dispatchMoves`), `Services/FolderWatcher.swift` (`DispatchSource .write` num fd de diretório)
- Evidência: MEDIUM CONFIDENCE (depende da semântica de `DispatchSource.makeFileSystemObjectSource(.write)` sobre um fd de **diretório**: dispara em add/remove/rename de entradas, não em appends aos bytes de um arquivo-filho já existente).
- Caminho de execução: writer cria `download.iso` direto no destino (curl/wget/scp/`>` shell — sem padrão temp→rename) → dir emite `.write` → debounce 0,5s → `processFolder` → `matchMoves` casa a regra → `dispatchMoves` tira snapshot, dorme 2s **uma vez**, re-checa → arquivo ainda crescendo → `isStable` falso → `continue` (pulado). **Não há retry.** O `DispatchSource` do diretório não volta a disparar pelos appends subsequentes ao arquivo. Se nenhuma outra atividade mexer no diretório, o arquivo nunca é reavaliado e nunca é movido.
- Invariante quebrado: "se um arquivo casou uma regra ativa e terminou de ser escrito, a regra eventualmente o move" → caminho que quebra: escrito in-place + scan único pegou-o mid-write → estado resultante: arquivo estável fica parado na origem indefinidamente → impacto: usuário acredita que a automação funcionou e não percebe o arquivo esquecido.
- Mitigação atual: só afeta writers que escrevem in-place. Chrome (`.crdownload`→rename) e Safari (`.download`) disparam `.write` no rename e são reprocessados. `curl -O`, `scp`, redirecionamento de shell, `dd` não.
- Solução sugerida: quando `dispatchMoves` pular um arquivo por instabilidade, reagendar um re-scan daquele folder após `fileStabilityWindow` (ex.: `watcher.scheduleCallback(for: folder)` ou um `Task.sleep` + reprocesso do subconjunto pulado), com um teto de tentativas por arquivo para não virar loop. Alternativa mais barata: adicionar um timer de "varredura de segurança" periódica (ex.: a cada 60s enquanto houver regra ativa) que reprocessa os source folders — cobre também o caso de o app ter sido aberto depois do download.
- Complexidade da correção: média (uma fila de re-tentativa com teto, ~30–50 linhas; ou um `Timer`/`Task` periódico ~15 linhas).
- Impacto:55 / Redução de risco:35 / Manut.:20 / Perf.:-10→0 / Simplicidade:0 / Esforço:35 / Risco:25 → VALUE≈ (55·.3)+(35·.25)+(20·.2)+(0·.1)+(0·.15)=16.5+8.75+4=29.25 / COST≈(35·.7)+(25·.3)=24.5+7.5=32 → **ROI 0.91**

> ROI recalculado 0.91; **mantido na lista principal** (não em NOT WORTH) por envolver "comportamento incorreto para o usuário" + "estado inconsistente" — o filtro de ROI baixo não se aplica a esses. ID ajustado para refletir severidade/impacto reais: **[MH-091]**.

---

### [ML-120] `moveItem(onCollision: .replace)` e `renameItem(onCollision: .replace)` parecem branches mortos e não registram undo do arquivo deslocado
- ROI: 1.20
- MEDIUM / código aparentemente morto + inconsistência de segurança de dados
- Arquivo: `Services/FileSystem/FileSystemService+Actions.swift` (`moveItem` case `.replace`; `performRenameOnDisk` case `.replace`)
- Evidência: HIGH CONFIDENCE para "sem undo do deslocado"; MEDIUM CONFIDENCE para "morto" (requer confirmação por grep de call sites).
- Problema: o caminho interativo de colisão de move (`moveOneResolvingCollision`) usa `moveItemReplacing` para `.replace` (que devolve `displacedTrashedURL` e permite registrar um passo `.trash` de undo). O `case .replace` dentro de `moveItem` faz `trashItem(destURL, resultingItemURL: nil)` — descarta a URL para onde o arquivo deslocado foi, então nenhum caller consegue registrar undo dele. O mesmo em `performRenameOnDisk` `.replace`. Se esses branches não têm caller (parecem não ter: `performRename` usa `.failIfExists`, o `UndoRedoService` usa `.keepBoth`, o loop de colisão usa `moveItemReplacing`), são branches inalcançáveis carregando risco de segurança de dados se alguém os usar no futuro sem perceber a diferença.
- Por que é um problema: (a) branch inalcançável = complexity budget desperdiçado + armadilha; (b) se ativado, viola DEV_RULES.md R4 ("ação destrutiva é undoável pelo caminho padrão OU avisa explicitamente") — um replace-move/rename mandaria o arquivo existente pro Lixo sem entrada de ⌘Z.
- Solução: confirmar por grep que não há callers e **remover** o `case .replace` de `moveItem` e de `performRenameOnDisk` (o enum `MoveCollisionPolicy` mantém `.replace` só onde `moveItemReplacing` o consome). Menos código, menos armadilha. Se houver caller, redirecioná-lo para `moveItemReplacing` + registro de undo.
- Complexidade: baixa (remoção após grep).
- Impacto:20 / Redução de risco:35 / Manut.:35 / Perf.:0 / Simplicidade:40 / Esforço:15 / Risco:20 → VALUE≈ (20·.3)+(35·.25)+(35·.2)+(0)+(40·.15)=6+8.75+7+6=27.75 / COST≈(15·.7)+(20·.3)=10.5+6=16.5 → **ROI 1.68**

> ID ajustado: **[ML-168]**.

---

### [MM-088] "Search everywhere" ignora a localização atual e sempre varre `~`
- ROI: 0.88
- MEDIUM / PRODUCT/UX — comportamento inesperado
- Arquivo: `Models/AppState/AppState+Navigation.swift` (`performSearchEverywhereRefresh`), `Services/FileSystem/FileSystemService.swift` (`loadRecursiveSearchResults(at: .userHome, …)`)
- Evidência: CONFIRMED (o root é literal `.userHome`, não `snapshot.target`).
- Problema: navegando em `/Volumes/ExternalDrive/Projetos` (ou `/Applications`, ou qualquer lugar fora de `~`) e ligando "search everywhere", a busca recursiva parte de `~` — não da pasta em que o usuário está. Não há nada na UI que diga isso.
- Por que é um problema: quebra a expectativa mais natural ("buscar em tudo a partir daqui"). Um usuário procurando um arquivo num HD externo grande liga o toggle e recebe zero resultados relevantes de `~`, lendo como "não existe".
- Impacto: confusão + falso negativo percebido; sem risco de dados.
- Solução: (a) simples — usar `snapshot.target` como root quando ele não for descendente de `~` (ou sempre); (b) alternativa de produto — manter `~` como default mas rotular o toggle/empty-state ("buscando em toda a sua pasta pessoal") e/ou oferecer "buscar a partir desta pasta". Decisão de produto — não implementar unilateralmente.
- Complexidade: baixa (troca de argumento) a média (UI de escopo).
- Impacto:40 / Redução de risco:10 / Manut.:10 / Perf.:0 / Simplicidade:0 / Esforço:20 / Risco:20 → VALUE≈ (40·.3)+(10·.25)+(10·.2)=12+2.5+2=16.5 / COST≈(20·.7)+(20·.3)=14+6=20 → **ROI 0.83**

> MEDIUM + ROI < 0.70? Não — 0.83 ≥ 0.70, permanece na lista principal. ID: **[MM-083]**.

---

### [SL-140] Documentação de regras (`SWIFT_LANG_RULES.md`) referencia `ARCHITECTURE_CODE_REVIEW.md` e finding IDs (CA-142, CB-189, CC-171, LR-2/3/4) que não existem no repo
- ROI: 1.40
- SUGGESTION / LOW — convenções não seguidas / drift de documentação
- Arquivos: `.agents/SWIFT_LANG_RULES.md` (R5 "Known gap (R5) ... Tracked as ARCHITECTURE_CODE_REVIEW.md CA-142"), `.agents/WILES_RULES.md` ("Lint-Enforced Rules" cita LR-2/LR-3/LR-4, CB-189, CC-171)
- Evidência: CONFIRMED (`find` não acha `ARCHITECTURE_CODE_REVIEW.md`; este relatório é a primeira materialização dele).
- Problema adicional: R5 afirma que `loadRealDirectoryContentsSync` "still has neither a cap nor a signal". O código atual **tem** cap (`directoryListingLimit = 20_000`) e sinal (`resultsTruncated` propagado por `performDirectoryRefresh`). A regra está desatualizada.
- Por que é um problema: regras que apontam para artefatos inexistentes ou descrevem o código errado corroem a confiança no conjunto de regras (que é, no geral, excelente).
- Solução: (a) manter este `ARCHITECTURE_CODE_REVIEW.md` como o doc de tracking canônico e re-ancorar as referências das regras nos IDs deste arquivo; (b) atualizar o texto de R5 para "cap + signal presentes; gap fechado".
- Complexidade: trivial (edição de docs).
- Impacto:20 / Redução de risco:10 / Manut.:45 / Perf.:0 / Simplicidade:10 / Esforço:10 / Risco:2 → VALUE≈ (20·.3)+(10·.25)+(45·.2)+(10·.15)=6+2.5+9+1.5=19 / COST≈(10·.7)+(2·.3)=7+0.6=7.6 → **ROI 2.50**

> ID ajustado: **[SL-250]**.

---

### [SL-095] `FolderNode.buildRootTree()` / `loadSubfolders` — I/O de disco recursivo síncrono; segurança depende só de convenção de call site
- ROI: 0.95
- SUGGESTION / PERFORMANCE (anti-beachball) — estrutural vs. implícito
- Arquivo: `Models/FolderNode.swift` (`buildRootTree`, `loadSubfolders`, `directoryHasSubfolder`)
- Evidência: MEDIUM CONFIDENCE (depende de quem chama `buildRootTree`; `loadChildren` já é embrulhado por `loadChildrenOffMainActor`).
- Problema: `buildRootTree()` faz `contentsOfDirectory` + `resourceValues` per-entry recursivamente para `/`, `/Users` e `~` de forma **síncrona**. Se algum call site o invocar de um `body`/`init` de View (em vez de `.task`/`Task.detached`), é beachball proporcional ao tamanho de `~`. A função não é `async` nem `nonisolated` — nada estrutural impede o mau uso (mesmo raciocínio de R3 "Off-Main Offload Must Be Structural").
- Solução: expor `buildRootTree()` como `static func buildRootTreeOffMainActor() async` (igual a `loadChildrenOffMainActor`) e/ou marcar a versão síncrona `nonisolated` + doc-comment "callers must run inside Task.detached". Verificar o call site atual.
- Complexidade: baixa.
- Impacto:15 / Redução de risco:20 / Manut.:20 / Perf.:15 / Simplicidade:0 / Esforço:15 / Risco:12 → VALUE≈ (15·.3)+(20·.25)+(20·.2)+(15·.1)=4.5+5+4+1.5=15 / COST≈(15·.7)+(12·.3)=10.5+3.6=14.1 → **ROI 1.06**

> ID ajustado: **[SL-106]**.

---

### [MM-105] `LocalHttpServerService.stop()` (`@MainActor`) usa `queue.sync` — pode congelar a UI atrás de I/O síncrono num mount lento
- ROI: 1.05
- MEDIUM / PERFORMANCE (anti-beachball) / lifecycle
- Arquivo: `Features/HttpSharing/LocalHttpServerService.swift` (`stop()`, `start()` chama `stop()`), `LocalHttpServerService+FileStreaming.swift` (`sendNextChunk` faz `fileHandle.read` síncrono no `queue`), `serveDirectoryListing` (`contentsOfDirectory` síncrono no `queue`)
- Evidência: HIGH CONFIDENCE (fluxo direto). Impacto real depende de a pasta compartilhada estar num volume lento/`/Volumes` — MEDIUM CONFIDENCE nesse recorte.
- Caminho: usuário fecha o `HttpShareSheet` / a janela → `stop()` roda no `@MainActor` → `queue.sync { … }`. Se o `queue` (serial) está no meio de um `fileHandle.read(upToCount: 64KB)` de um arquivo num SMB/HD externo com stall, ou de um `contentsOfDirectory` num diretório enorme/lento, `queue.sync` bloqueia a main thread até terminar. `serveDirectoryListing` inteiro roda síncrono no `queue` sem chunking, então o pior caso não tem teto de 64KB.
- Por que é um problema: `WILES_RULES.md` "Native-First" exige avisar proativamente sobre qualquer padrão de I/O que possa congelar a UI. Aqui o `stop()` de um recurso de rede depende de trabalho de disco potencialmente lento na mesma fila serial.
- Impacto: beachball momentâneo ao parar o compartilhamento quando a pasta está num mount lento. Sem risco de dados.
- Solução sugerida: `stop()` seta `isRunning=false`/`serverURL=nil` imediatamente no `@MainActor` e agenda o teardown pesado com `queue.async` (não `.sync`). O `listener?.cancel()` + `connections.forEach { $0.cancel() }` não precisam de barreira síncrona para a UI ficar consistente. Alternativa: mover a leitura de diretório do listing para fora do `queue` (própria `Task.detached`), devolvendo só o HTML pronto.
- Complexidade: baixa/média (`stop()`: baixa; listing off-queue: média).
- Impacto:35 / Redução de risco:30 / Manut.:10 / Perf.:25 / Simplicidade:0 / Esforço:25 / Risco:25 → VALUE≈ (35·.3)+(30·.25)+(10·.2)+(25·.1)=10.5+7.5+2+2.5=22.5 / COST≈(25·.7)+(25·.3)=17.5+7.5=25 → **ROI 0.90**

> MEDIUM + ROI 0.90 ≥ 0.70 → permanece na lista principal. ID: **[MM-090]**.

---

### [ML-133] `ThumbnailService.shared` (singleton) guarda `prefetchTask` — estado "o que ESTA janela está pré-carregando", duas janelas disputam o slot
- ROI: 1.33
- MEDIUM / ARCHITECTURAL CONCERN — regra própria do projeto ("Shared service ... must not hold a mutable property representing what THIS window is doing right now")
- Arquivo: `Services/ThumbnailService.swift` (`prefetchTask`, `prefetchThumbnails`), consumido por um modificador de View por-janela
- Evidência: HIGH CONFIDENCE para a violação da regra; LOW-MEDIUM para o impacto (o cache é global; o pior caso é CPU desperdiçado e prefetch cancelado cedo).
- Problema: `SmartFolderService`/`LocalHttpServerService`/`NetworkDiscoveryService` já foram migrados para instância por-`AppState` exatamente por essa regra (WILES_RULES.md "Singleton Services With Session State Need an Explicit Owner — BLOCKING"). `ThumbnailService.shared.prefetchTask` é o mesmo padrão: cada janela, ao navegar, chama `prefetchThumbnails` que faz `prefetchTask?.cancel()` — cancelando o prefetch da OUTRA janela. Com duas janelas em pastas diferentes, elas cancelam o prefetch uma da outra continuamente; nenhuma completa o prefetch enquanto a outra navega.
- Por que é um problema: viola uma regra marcada BLOCKING no próprio projeto; degrada o benefício do prefetch em uso multi-janela (as duas janelas caem no fallback lazy `loadThumbnail` por célula). O cache em si (bom) é legitimamente global e deve continuar `.shared`.
- Solução: separar. O `NSCache` + índice de mtime + dedup `inFlight` continuam `.shared` (recurso global, sem estado de sessão). Só o `prefetchTask` (a "sessão" de prefetch de uma janela) vira estado por-`AppState`: um pequeno `ThumbnailPrefetcher` por janela que chama os métodos `nonisolated` do cache compartilhado. ~40 linhas, baixo risco.
- Complexidade: baixa/média.
- Impacto:25 / Redução de risco:20 / Manut.:35 / Perf.:15 / Simplicidade:10 / Esforço:25 / Risco:15 → VALUE≈ (25·.3)+(20·.25)+(35·.2)+(15·.1)+(10·.15)=7.5+5+7+1.5+1.5=22.5 / COST≈(25·.7)+(15·.3)=17.5+4.5=22 → **ROI 1.02**

> ID ajustado: **[ML-102]**.

---

### [MM-095] Refresh de diretório descartado durante rename não é reprocessado — mudanças externas podem ficar invisíveis até nova navegação
- ROI: 0.95
- MEDIUM / BUG — máquina de estados / lifecycle
- Arquivo: `Models/AppState/AppState+Navigation.swift` (`applyLoadedItems` guard `renamingURL == nil`), `Models/AppState/AppState+Operations.swift` (`enterRenameForNewlyCreated`)
- Evidência: MEDIUM CONFIDENCE.
- Problema (mais amplo que [LL-166]): enquanto `fileSystem.renamingURL != nil`, TODA aplicação de resultado de refresh é jogada fora (`applyLoadedItems` early-return). Se, durante um rename que o usuário deixa aberto por vários segundos (renomeando algo com nome longo, pensando), um FSEvents/monitor dispara um refresh porque um processo externo criou/apagou arquivos na pasta, esse resultado é descartado e **não há re-disparo agendado** quando o rename termina. `onRenameCleared` só faz `renamingURL = nil` — não chama `refreshCurrentDirectory()`. A lista só reconcilia no próximo evento de FSEvents *após* o fim do rename (que pode não vir se a atividade externa já cessou) ou na próxima navegação.
- Invariante: "a lista reflete o conteúdo real da pasta atual" → caminho que quebra: mudança externa durante um rename aberto → resultado descartado + sem re-disparo → estado: lista desatualizada silenciosamente.
- Solução: ao limpar `renamingURL` (no `onRenameCleared` e no caminho de commit do rename), chamar `refreshCurrentDirectory()` uma vez. Barato e idempotente.
- Complexidade: baixa.
- Impacto:35 / Redução de risco:25 / Manut.:15 / Perf.:0 / Simplicidade:5 / Esforço:10 / Risco:12 → VALUE≈ (35·.3)+(25·.25)+(15·.2)+(5·.15)=10.5+6.25+3+0.75=20.5 / COST≈(10·.7)+(12·.3)=7+3.6=10.6 → **ROI 1.93**

> Substitui/engloba o [LL-166] anterior. ID: **[MM-193]**. (O [LL-166] "spinner preso" vira um sub-caso — a mesma correção resolve os dois.)

---

### [ML-115] `AutoOrganizationRule.isSelfReferential` é código morto; a validação anti-self-reference usa comparação diferente e não cobre symlinks
- ROI: 1.15
- MEDIUM / código morto + inconsistência de API interna + comportamento incorreto silencioso
- Arquivos: `Models/AutoOrganizationRule.swift` (`isSelfReferential`), `Views/Modals/AutoOrganizationSheet.swift` (`canAddRule` linha ~256), `Services/AutoOrganizationService.swift` (`dispatchMoves`)
- Evidência: CONFIRMED (grep: `isSelfReferential` só aparece na definição + um comentário; zero consumidores).
- Problema: (a) `isSelfReferential` (`sourceURL.resolvingSymlinksInPath() == destinationURL.resolvingSymlinksInPath()`) nunca é chamado — branch/propriedade sem consumidor. (b) A checagem real que impede source==dest está em `canAddRule` e usa `sourceURL.standardizedFileURL != destinationURL.standardizedFileURL` — **sem** resolução de symlink. Uma regra com source `~/Downloads` e dest um symlink para `~/Downloads` passa por `canAddRule`. (c) Em runtime, `dispatchMoves` chama `moveItem` que lança `itemAlreadyInDestination` por arquivo → `ErrorReporter.report` a cada scan, sem feedback ao usuário — a regra parece quebrada silenciosamente.
- Solução: usar `AutoOrganizationRule.isSelfReferential` em `canAddRule` (substituindo a comparação `standardizedFileURL` ad-hoc) e como guard em `processFolder`/`dispatchMoves`. Uma verdade só, com resolução de symlink, e a propriedade deixa de ser morta.
- Complexidade: baixa.
- Impacto:30 / Redução de risco:20 / Manut.:35 / Perf.:0 / Simplicidade:25 / Esforço:12 / Risco:12 → VALUE≈ (30·.3)+(20·.25)+(35·.2)+(25·.15)=9+5+7+3.75=24.75 / COST≈(12·.7)+(12·.3)=8.4+3.6=12 → **ROI 2.06**

> ID ajustado: **[ML-206]**.

---

### [MM-120] "Change all default app…" altera o handler do tipo de arquivo no sistema inteiro sem confirmação; o rótulo com "…" promete um diálogo que não existe
- ROI: 1.20
- MEDIUM / PRODUCT/UX — ações de efeito externo sem confirmação
- Arquivo: `Views/Components/SharedFileItemContextMenu.swift` (`changeDefaultAppMenu` linha ~209), `Services/OpenWithService.swift` (`setDefaultApplication`)
- Evidência: CONFIRMED (o `Button` chama `setDefaultApplication` direto; sem `confirmationDialog`).
- Problema: um item de menu de contexto muda `NSWorkspace.setDefaultApplication` para a extensão — efeito **global do sistema**, afeta todos os apps, não só o Wiles. Não há confirmação, nem undo, nem toast de "feito". O rótulo `changeAllDefaultAppEllipsis` termina em "…", que na convenção Apple sinaliza "abre um diálogo" — aqui não abre nada, executa direto.
- Por que é um problema: GENERAL_RULES/DEV_RULES — "ações difíceis de reverter ou de efeito externo: confirmar antes". Mudar o app padrão de `.pdf` para o sistema todo a partir de um clique acidental num submenu é exatamente esse caso. E o "…" mente sobre o fluxo.
- Impacto: surpresa do usuário; efeito fora do app; sem sinal de que ocorreu.
- Solução: (a) `confirmationDialog` "Tornar {App} o app padrão para arquivos .{ext} em todo o sistema?" antes de aplicar; ou (b) no mínimo um feedback (haptic + toast/estado) pós-ação; e remover o "…" se não houver diálogo, ou mantê-lo se (a) for adotada.
- Complexidade: baixa.
- Impacto:35 / Redução de risco:25 / Manut.:5 / Perf.:0 / Simplicidade:0 / Esforço:12 / Risco:8 → VALUE≈ (35·.3)+(25·.25)+(5·.2)=10.5+6.25+1=17.75 / COST≈(12·.7)+(8·.3)=8.4+2.4=10.8 → **ROI 1.64**

> ID ajustado: **[MM-164]**.

---

### [ML-118] `TerminalViewCache.tearDown()` depende de reflection sobre API interna do SwiftTerm para achar o pid — regressão de SwiftTerm = vazamento de processo de shell por janela
- ROI: 1.18
- MEDIUM / BUG latente (process leak) — dependências / lifecycle
- Arquivo: `Views/Content/TerminalViewCache.swift` (`shellPid(of:)` via `Mirror`), `Views/Content/IntegratedTerminalView.swift` (spawn)
- Evidência: HIGH CONFIDENCE de que é frágil; MEDIUM CONFIDENCE de que quebra (depende de bump do SwiftTerm renomear/reestruturar `process`/`shellPid`).
- Caminho: fechar janela → `MainContentView.onDisappear` → `terminalViewCache.tearDown()` → `Mirror(reflecting: view).children.first { $0.label == "process" }` → `.children.first { $0.label == "shellPid" }`. Se o SwiftTerm mudar esses nomes internos, `shellPid` retorna `nil` → fallback `send(txt: "exit\r")`, que — como o próprio comentário admite — é engolido por `vim`/`tail -f`/qualquer processo em foreground → `/bin/zsh -l` + filhos ficam órfãos, um conjunto por janela fechada com o terminal aberto.
- Por que é um problema: process leak silencioso, só detectável no Activity Monitor; a única salvaguarda é uma string de reflection não testada. `improvements.md` já registra SwiftTerm como dependência vendored/travada — um bump futuro é plausível.
- Solução: (a) teste de integração que abre um terminal, lê o pid via o mesmo caminho de reflection e **falha** se vier `nil` para um terminal vivo — assim um bump do SwiftTerm quebra o CI, não a produção silenciosamente; (b) ou capturar o pid uma vez logo após `startProcess` (quando a estrutura é conhecida-boa) e guardá-lo no `TerminalViewCache`, em vez de reflectir no teardown; (c) ou abrir issue no SwiftTerm pedindo `var shellPid: pid_t?` público.
- Complexidade: baixa (teste) / baixa (capturar no spawn).
- Impacto:30 / Redução de risco:35 / Manut.:25 / Perf.:0 / Simplicidade:0 / Esforço:18 / Risco:10 → VALUE≈ (30·.3)+(35·.25)+(25·.2)=9+8.75+5=22.75 / COST≈(18·.7)+(10·.3)=12.6+3=15.6 → **ROI 1.46**

> Envolve "process leak" → não descartável por ROI mesmo se fosse baixo. ID: **[ML-146]**.

---

### [MM-072] Saves de preferências debounced são perdidos se o app é encerrado dentro da janela de debounce (sem flush em `applicationWillTerminate`)
- ROI: 0.72
- MEDIUM / BUG — persistência (viola "Complete State Persistence")
- Arquivos: `Models/AppState/Stores/Preferences/ViewPreferences.swift` (`scheduleIconSizeSave` 0.3s, `schedulePerFolderViewModesSave` 0.5s, `scheduleListColumnStatesSave` 0.3s), `MainContentView` (`scheduleSidebarWidthSave` 0.4s), `Services/AutoOrganizationRuleStore.swift` (`bumpStats` debounce 2s), `App/WilesApp.swift` (sem delegate de término)
- Evidência: HIGH CONFIDENCE (o `DispatchWorkItem`/`Task.sleep` não executou → o `UserDefaults.set` não aconteceu → `⌘Q` mata o processo antes).
- Caminho: usuário arrasta o slider de tamanho de ícone e solta → `⌘Q` em < 300ms → `pendingIconSizeSave` nunca dispara → próximo launch restaura o valor antigo. Idem largura da sidebar (arrastar divisória + `⌘Q`), estados de coluna, per-folder view modes, e stats de auto-org (janela de 2s — a mais fácil de perder).
- Por que é um problema: `WILES_RULES.md` "Complete State Persistence" exige que TODA preferência seja salva e restaurada exatamente. `.onDisappear` não roda em `⌘Q` com janelas abertas, e mesmo se rodasse não faz flush dos pendentes.
- Impacto: perda ocasional de ajuste de preferência (não de dados do usuário). Frustante e difícil de diagnosticar ("por que meu tamanho de ícone não salvou?").
- Solução: um `NSApplicationDelegate.applicationWillTerminate` (ou `.onReceive(NSApplication.willTerminateNotification)` no root) que chama um `flushPendingSaves()` em `ViewPreferences`/`AutoOrganizationRuleStore` — cada um executa e cancela seus `pending*` work items sincronicamente. ~30 linhas, centraliza um invariante de persistência.
- Complexidade: baixa/média.
- Impacto:25 / Redução de risco:20 / Manut.:25 / Perf.:0 / Simplicidade:-5→0 / Esforço:30 / Risco:20 → VALUE≈ (25·.3)+(20·.25)+(25·.2)=7.5+5+5=17.5 / COST≈(30·.7)+(20·.3)=21+6=27 → **ROI 0.65**

> MEDIUM + ROI 0.65 < 0.70 → tecnicamente NOT WORTH. Mas envolve "estado inconsistente / persistência incorreta" e viola uma regra explícita do projeto → mantido na lista principal com a discrepância anotada. ID: **[MM-065]**.

---

### [SM-060] `MainContentView.mainSplitView` depende de `appState.selection.selectedURLs` via `.onChange` → body do container da janela re-executa a cada tecla de seleção
- ROI: 0.60
- SUGGESTION / PERFORMANCE — body recomputation
- Arquivo: `Views/Content/MainContentView.swift` (`.onChange(of: appState.selection.selectedURLs)` em `mainSplitView`)
- Evidência: MEDIUM CONFIDENCE (o `.onChange(of:)` registra dependência no body onde está declarado; o SwiftUI pode absorver via diffing — precisa de profiling para confirmar impacto).
- Problema: `mainSplitView` é o body do container inteiro da janela (HSplitView + toda a cadeia `.modifier(WilesModalSheets)` + backgrounds). `.onChange(of: appState.selection.selectedURLs)` faz esse body observar `selectedURLs`, que muda a cada seta/clique/marquee-tick. Em navegação por teclado com key-repeat (~10–20 Hz) numa pasta grande, o body do container re-avalia a cada tick. O projeto tem regra BLOCKING sobre estado de alta frequência não invalidar rendering — seleção fica na fronteira ("alta frequência" durante key-repeat/marquee).
- Solução: mover `cancelRenameIfSelectionChanged` para um ponto mais folha — p.ex. um `.onChange` dentro de `FileListView`/`FileGridView` (que já re-renderizam por seleção de qualquer forma), ou observar só `windowUIState.renameItem != nil` como gate barato antes de tocar em `selectedURLs`. Reduz a superfície de re-render do container.
- Complexidade: baixa.
- Impacto:15 / Redução de risco:10 / Manut.:10 / Perf.:35 / Simplicidade:5 / Esforço:15 / Risco:20 → VALUE≈ (15·.3)+(10·.25)+(10·.2)+(35·.1)+(5·.15)=4.5+2.5+2+3.5+0.75=13.25 / COST≈(15·.7)+(20·.3)=10.5+6=16.5 → **ROI 0.80**

> ID ajustado: **[SM-080]**.

---

### [LL-090] `NetworkDiscoveryService` — timeout Tasks de resolução não canceláveis; callback de resultados pode ressuscitar resolvers após `stop()`
- ROI: 0.90
- LOW / BUG (resource leak limitado) — cancellation / lifecycle
- Arquivo: `Services/NetworkDiscoveryService.swift` (`beginResolving` timeout `Task`; `browseResultsChangedHandler` → `Task { @MainActor }`)
- Evidência: MEDIUM CONFIDENCE.
- Problema: (a) o `Task { @MainActor … Task.sleep(resolveTimeout) … finishResolving(nil) }` por resolver não é guardado nem cancelado — em `stop()` ele fica vivo 5s e depois no-opa via `guard resolvers[name] === expected`. Um orfão por share resolvido. (b) `stop()` limpa tudo, mas um `browseResultsChangedHandler` já enfileirado como `Task { @MainActor }` pode rodar depois e repovoar `advertisedNames` + criar resolvers pós-stop (o `guard let self` passa — instância por-janela ainda viva). Esses resolvers vazam até o próximo `stop()`.
- Impacto: pequeno (resultados mDNS são leves; NWConnections extras por alguns segundos). Sem crash, sem dados.
- Solução: guardar os timeout tasks numa coleção e cancelá-los em `finishResolving`/`stop()`; adicionar um flag `isStopped` checado no início de `updateDiscoveredShares` para descartar callbacks tardios.
- Complexidade: baixa.
- Impacto:15 / Redução de risco:20 / Manut.:15 / Perf.:5 / Simplicidade:0 / Esforço:15 / Risco:12 → VALUE≈ (15·.3)+(20·.25)+(15·.2)+(5·.1)=4.5+5+3+0.5=13 / COST≈(15·.7)+(12·.3)=10.5+3.6=14.1 → **ROI 0.92**

> Envolve "resource leak" (ainda que limitado) → não descartado por ROI. ID: **[LL-092]**.

---

### [SL-085] `@State` sem leitor em `FileListView` (`lastWindowWidth`, `hoveredURL`)
- ROI: 0.85
- SUGGESTION / LOW — código morto
- Arquivo: `Views/Content/FileListView.swift` (`@State private var lastWindowWidth`, `@State private var hoveredURL`)
- Evidência: MEDIUM CONFIDENCE (grep no arquivo não mostra leitura; confirmar que nenhum closure/binding os usa).
- Problema: `lastWindowWidth` é escrito em `onGeometryWidthChange` e nunca lido; `hoveredURL` não aparece em nenhum `body`/modificador do arquivo (o hover é gerido por `.hoverHighlight`). Estado morto = ruído + falsa impressão de que algo depende dele.
- Solução: remover ambos (e o `_ =`/atribuição associada). Se `hoveredURL` era para um recurso não terminado, deixar um TODO explícito.
- Complexidade: trivial.
- Impacto:5 / Redução de risco:5 / Manut.:20 / Perf.:2 / Simplicidade:20 / Esforço:5 / Risco:3 → VALUE≈ (5·.3)+(5·.25)+(20·.2)+(2·.1)+(20·.15)=1.5+1.25+4+0.2+3=9.95 / COST≈(5·.7)+(3·.3)=3.5+0.9=4.4 → **ROI 2.26**

> ID ajustado: **[SL-226]**.

---

### [SL-070b] Acessibilidade: componentes-folha interativos/decorativos sem tratamento explícito
- ROI: 0.90
- SUGGESTION / LOW — acessibilidade / consistência
- Arquivos: `Views/Components/FavoriteToggleButton.swift` (botão sem `.accessibilityLabel`), `Views/Components/FileItemIconView.swift`, `Views/Components/TagsIndicatorView.swift`, `Views/Components/ImageThumbnailView.swift` (decorativos sem `.accessibilityHidden(true)`)
- Evidência: MEDIUM CONFIDENCE (grep: sem `accessibility*` nesses arquivos; a `linha`/row pai geralmente carrega label, então o impacto é parcial).
- Problema: `SWIFT_LANG_RULES.md` "Mandatory VoiceOver Accessibility" pede label/hint/traits em todo elemento interativo. `FavoriteToggleButton` é o gap real (VoiceOver anuncia "botão" sem dizer o quê). Os decorativos, sem `.accessibilityHidden(true)`, fazem o VoiceOver ler descrições de imagem cruas dentro de uma linha que já tem label.
- Solução: `.accessibilityLabel(appState.tr(.addToFavorites/removeFromFavorites))` + `.accessibilityAddTraits(.isButton)` no toggle; `.accessibilityHidden(true)` nos três decorativos.
- Complexidade: trivial.
- Impacto:15 / Redução de risco:5 / Manut.:15 / Perf.:0 / Simplicidade:0 / Esforço:12 / Risco:3 → VALUE≈ (15·.3)+(5·.25)+(15·.2)=4.5+1.25+3=8.75 / COST≈(12·.7)+(3·.3)=8.4+0.9=9.3 → **ROI 0.94**

> ID ajustado: **[SL-094]**.

---

### [SL-055] `ArchiveService.collidesWithExisting` compara nomes case-sensitive; num volume case-insensitive pode não detectar colisão e extrair flat por cima
- ROI: 0.55
- SUGGESTION / LOW / BUG (edge case) — filesystem
- Arquivo: `Services/ArchiveService.swift` (`collidesWithExisting`)
- Evidência: MEDIUM CONFIDENCE.
- Problema: `topLevelEntryNames.isDisjoint(with: existingNames)` usa igualdade de `String` (case-sensitive). Num APFS case-insensitive, uma entrada `Foo/` no zip vs. `foo` no disco não conta como colisão → `canExtractFlat == true` → `ditto`/`tar` extrai por cima e pode sobrescrever `foo`.
- Impacto: raro (precisa diferença só de caixa entre conteúdo do zip e do destino) e o resultado é sobrescrever um arquivo existente, não perda além do Lixo? — na verdade `ditto -x -k` sobrescreve sem mandar pro Lixo. Então há risco pequeno de sobrescrever sem rede de segurança.
- Solução: comparar com `caseInsensitiveCompare`/normalizando ambos os lados para lowercased num `Set`, quando o volume do destino for case-insensitive (ou sempre, conservador).
- Complexidade: baixa.
- Impacto:15 / Redução de risco:25 / Manut.:5 / Perf.:0 / Simplicidade:0 / Esforço:10 / Risco:10 → VALUE≈ (15·.3)+(25·.25)+(5·.2)=4.5+6.25+1=11.75 / COST≈(10·.7)+(10·.3)=7+3=10 → **ROI 1.18**

> Envolve "sobrescrever arquivo do usuário sem rede" → não descartado por ROI. ID: **[SL-118]**.

---

### [SL-050] `SmartFolderService.fetchFileItems` não checa cancelamento no loop — troca rápida de smart folder ainda resolve 2000 `FileItem` inúteis
- ROI: 0.50
- SUGGESTION / LOW — cancellation / performance
- Arquivo: `Features/SmartFolders/SmartFolderService.swift` (`fetchFileItems`)
- Evidência: HIGH CONFIDENCE do comportamento; LOW do impacto (limitado a 2000, ~1–2s de CPU/IO).
- Problema: `Task.detached` sem parent, loop `for path in cappedPaths { items.append(FileItem.load(...)) }` sem `Task.isCancelled`. O token de staleness (`currentQueryToken`) impede aplicar resultados obsoletos, mas o trabalho roda até o fim. Trocar de smart folder 3x rápido = 3 resoluções completas de 2000 itens em paralelo.
- Solução: guardar o `Task` retornado por `fetchFileItems` (ou torná-lo filho via `runQuery`) e cancelá-lo no início de `runQuery`; checar `Task.isCancelled` no topo do loop.
- Complexidade: baixa.
- Impacto:10 / Redução de risco:5 / Manut.:10 / Perf.:20 / Simplicidade:0 / Esforço:15 / Risco:12 → VALUE≈ (10·.3)+(5·.25)+(10·.2)+(20·.1)=3+1.25+2+2=8.25 / COST≈(15·.7)+(12·.3)=10.5+3.6=14.1 → **ROI 0.59**

> **NOT WORTH** (SUGGESTION, ROI 0.59, sem crash/dados/leak). Uma linha em NOT WORTH.

<!-- end of findings -->

---

## NOT WORTH

Uma linha cada. Filtro: LOW + ROI < 1.00 → NOT WORTH; MEDIUM + ROI < 0.70 → NOT WORTH. Itens que envolvem crash/perda/leak/estado inconsistente foram mantidos na lista principal com a discrepância anotada, não aqui.

- [SL-070] LOW/ARCH — `BackgroundOperationsService.shared` guarda `activeTasks`/`cancellationHandlers` app-wide e mostra progresso em todas as janelas; migrar para por-`AppState` só se incomodar — ROI 0.29.
- [SL-059] SUGGESTION/CANCELLATION — `SmartFolderService.fetchFileItems` não checa `Task.isCancelled` no loop; troca rápida de smart folder resolve até 2000 `FileItem` inúteis (token de staleness já impede aplicar resultado obsoleto) — ROI 0.59.
- [SL-045] LOW/PERF — `FilePropertiesSheet.loadProperties` faz 3 `await` sequenciais (`fetchProperties`, `extractExif`, permissões) em vez de `async let` concorrente; irrelevante para arquivo local, perceptível só em `/Volumes` — ROI ~0.5.
- [SL-040] LOW/PERF — `SyntaxHighlighterService.maxHighlightChars` comparado com `utf16.count` mas truncado com `prefix()` (Character count); cap aproximado, sem impacto funcional — ROI ~0.4.
- [SL-038] LOW/PERF — `performRecursiveSearch` usa `Array.insert(at:)` (O(n) por shift) para inserção binária; teto de 2000 limita o custo — ROI ~0.4.
- [SL-035] LOW/COSMETIC — `DuplicateDetectionService.confirmedDuplicateGroups` itera `Dictionary` (ordem não-determinística) → ordem dos grupos varia entre execuções; usuário revisa a seleção mesmo assim — ROI ~0.35.
- [SL-030] LOW/COSMETIC — `DuplicateDetectionService.keepFirstOrder` instável quando profundidade E `dateCreated` empatam → "qual manter" não-determinístico numa fração dos grupos — ROI ~0.3.
- [SL-030b] LOW/PERF — `NavigationStore.addToRecents` faz 1 read + 1 write de array de até 50 strings no `UserDefaults` a cada navegação de pasta; bounded, mas evitável com merge só na saída — ROI ~0.3.
- [SL-028] LOW/PERF — `BoundedFolderNodeCache.cachedURLs` aloca um `Set` novo a cada acesso; verificar frequência de leitura na sidebar — ROI ~0.3.
- [SL-025] LOW/EDGE — `ArchiveService.readStdout` no cap-hit faz `process.terminate()` (SIGTERM) + loop de drain; um filho que ignore SIGTERM trava o loop (improvável p/ `unzip`/`tar`) — ROI ~0.25.
- [SL-025b] LOW/EDGE — `PasteboardService.readTextForClipboard`: se `resourceValues(.fileSizeKey)` falhar (`size == nil`), lê o arquivo inteiro sem cap; combinação rara (stat falha, read sucede) — ROI ~0.25.
- [SL-020b] LOW/CHURN — `SidebarView`: alternar a visibilidade de uma seção anterior (FAVORITES/RECENTS) muda a estrutura do `ViewBuilder` e pode fazer o SwiftUI ver a seção NETWORK como nova → `stop()`+`start()` do mDNS; `start()` tem guard, só desperdício — ROI ~0.2.
