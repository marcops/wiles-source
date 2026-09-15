# Análise: Polling nos Testes — Causas, Categorias e ROI

Documento gerado em 2026-09-15 a pedido do usuário, depois de investigar por que
`swift test` tem várias suítes lentas (ex.: `testAutoOrganizationTests` em 30.2s) e por
que o código de teste usa tanto polling em vez de algum mecanismo de notificação
("semáforo", `await` direto, etc.).

**Importante, antes de tudo:** nada aqui foi alterado ainda. Isto é só a análise pedida.

## Ponto central: isto é ganho para o usuário, ou só para o teste?

**Curta e direta: só para o teste.** Nenhuma das mudanças discutidas neste documento
muda o comportamento real do app para quem usa o Wiles. São todas sobre a suíte de
testes rodar mais rápido e de forma mais determinística (menos "flaky"). O valor real
é indireto: ciclo de feedback mais rápido pro desenvolvedor (você/eu) e CI mais barato —
não uma feature, correção de bug visível, ou melhora de performance que o usuário final
perceberia.

Isso é diferente dos bugs reais que já corrigimos nesta sessão (ex.: `LaunchServicesGate`
não deixava nada rodar em paralelo de verdade, `FolderPickerSheet` congelava o app ao
escolher uma pasta local) — aqueles SIM eram ganho real pro usuário. O que segue abaixo
não é.

## Por que existe tanto polling

Toda vez que um teste precisa saber "o trabalho assíncrono já terminou?", ele tem duas
opções: (a) ter um sinal direto para `await` (uma `Task` que pode capturar, uma
`Notification` moderna como async sequence, um `continuation`), ou (b) perguntar
repetidamente "já terminou?" a cada N milissegundos até um timeout. A codebase usa (b)
em ~27 arquivos de teste porque, na maioria dos casos, a opção (a) **não existe hoje**
no código de produção — não por preguiça, mas porque o código de produção foi
desenhado de propósito para ser "dispare e esqueça" (fire-and-forget), do jeito que uma
ação de UI real precisa ser.

## Metodologia do cálculo de ROI (%)

Para cada categoria, calculei:

```
tempo_atual      = tempo real medido/estimado gasto em espera (sleep/poll) hoje
tempo_pos_fix    = tempo estimado gasto em espera depois da mudança
% redução        = (tempo_atual − tempo_pos_fix) / tempo_atual × 100

custo            = esforço estimado de implementação (Baixo / Médio / Alto),
                    mapeado em pontos: Baixo=1, Médio=3, Alto=8
                    (escala não-linear porque "Alto" aqui normalmente significa
                    mexer em código de produção sensível, não só no teste)

risco            = chance de introduzir uma regressão/flakiness nova (Baixo/Médio/Alto)

ROI (%)          = % redução ÷ custo (pontos), normalizado para 0–100%
                    entre as opções candidatas (a de maior % redução/custo = 100%,
                    as outras em proporção a ela)
```

**Limitação honesta:** os tempos de "espera" por categoria são estimados lendo o
código (`Task.sleep`, tamanho do loop de `pollUntilTrue`, janelas de debounce), não de
um profiling isolado de cada teste. Os números de tempo total por suíte (30.2s, 10.2s,
etc.) são medidos de verdade (do `swift test` real); a fatia disso que é
especificamente polling/sleep é estimativa a partir da leitura do código.

---

## Categoria 1 — Operações do AppState que disparam `Task.detached` internamente

**Arquivos (12):**
`Tests/WilesTests/Services/AppStateOperationsExtraTests.swift`,
`AppStatePasteAndArchiveTests.swift`, `AppStateColumnsAndActionsAsyncTests.swift`,
`AppStateOperationsFailureTests.swift`, `AppStateOperationsCreateFolderTests.swift`,
`AppStateOperationsHandleDropTests.swift`,
`Tests/WilesTests/Models/AppState/AppStateMoveUndoTests.swift`,
`AppStateFavoritesMoveTests.swift`, `AppStateSmartFolderTests.swift`,
`Tests/WilesTests/Models/AppState/Stores/NavigationStoreTests.swift`,
`Tests/WilesTests/Navigation/AppStateNavigateToVolumesTests.swift`,
`AppStateDirectoryRefreshTests.swift`, `AppStateNavigationExtraTests.swift`,
`Tests/WilesTests/Models/AppState/AppStateCoreTests.swift`.

**Causa raiz:** os métodos do `AppState` chamados aqui (ex.: mover, colar, criar pasta)
internamente fazem `Task.detached { ... }` e retornam `Void` — não devolvem nada que dê
pra esperar. Isso é proposital: um botão de SwiftUI ou uma ação de menu do AppKit não
consegue fazer `await` dentro do handler, então a API de produção precisa ser
"dispare e esqueça" por natureza. O teste, sem um handle pra esperar, fica perguntando
"o `Task.detached` já terminou?" a cada 200ms (helper `pollUntilTrue`, até 20 tentativas
= teto de 4s, mas sai assim que a condição vira verdadeira).

**Correção proposta (revisada após sua observação):** adicionar
`@discardableResult` no retorno desses métodos, devolvendo a `Task<Void, Never>` que já
existe internamente. Como o retorno é `@discardableResult`, **nenhum código real do app
precisa mudar** — um botão que já ignora o retorno continua ignorando, compila igual,
comporta-se igual. Só o teste passa a poder capturar essa `Task` e fazer
`await task.value` em vez de fazer polling.

**Ganho para o usuário: nenhum.** Zero mudança de comportamento visível.

**Estimativa:**
- tempo_atual (espera por polling, agregado): ~4–6s dos ~13s combinados de
  `testAppStateOperationsExtraTests` (10.2s) + fatia de `testAppStateCoreTests` (3.0s)
- tempo_pos_fix: ~0.3–0.8s (o `await` resolve no instante exato em que o `Task`
  termina, sem esperar o próximo "tick" de 200ms)
- % redução: ~85–90% do tempo de espera nesses testes específicos
- custo: Baixo (1 ponto) — muda assinatura de retorno, não lógica; testes reescritos
  um a um trocando `await pollUntilTrue {...}` por `await task.value`
- risco: Baixo — mudança aditiva e não-quebrante
- **ROI: 100%** (referência — melhor relação ganho/custo de todas as categorias)

---

## Categoria 2 — Eventos reais de sistema de arquivos (FSEvents)

**Arquivos (2):**
`Tests/WilesTests/Services/DirectoryMonitorTests.swift`,
`Tests/WilesTests/Services/FolderWatcherTests.swift`.

**Causa raiz:** testam o `FSEventStream` de verdade (via `DirectoryMonitor` /
`FolderWatcher`, produção). O callback do FSEvents é assíncrono por natureza do
sistema operacional — não existe "esperar sincronamente" por um evento do Finder/kernel.

**Correção proposta:** envolver o callback existente num `withCheckedContinuation` em
vez de fazer polling numa flag. Ainda precisa de um timeout de segurança (o evento pode,
em teoria, nunca chegar), mas resolve no instante exato em que o evento real dispara,
em vez de esperar até o próximo "tick" do poll (até 200ms de atraso extra por evento).

**Ganho para o usuário: nenhum.** É puramente sobre como o teste espera, não sobre o
`DirectoryMonitor` de produção (que já está bem implementado, revisado nesta sessão).

**Estimativa:**
- tempo_atual: fatia de `testDirectoryMonitorTests` (3.3s) + `testFolderWatcher` (1.6s)
  — provavelmente ~1–2s é "slop" de polling somado nesses dois
- tempo_pos_fix: ~0.5–1s (ainda depende da latência real do FSEvents, só remove o
  atraso do polling em cima disso)
- % redução: ~40–50% do tempo de espera
- custo: Médio (3 pontos) — só código de teste, mas `withCheckedContinuation` exige
  cuidado pra não vazar a continuation nem resolvê-la duas vezes
- risco: Médio — bug de continuation mal-feita trava o teste em vez de dar timeout
- **ROI: ~35%**

---

## Categoria 3 — Notificações reais do sistema operacional / Spotlight

**Arquivos (2):**
`Tests/WilesTests/Services/SystemAppearanceObserverTests.swift` (posta uma
`DistributedNotificationCenter` de verdade — comentário no próprio código diz
"no fake-able seam"), `Tests/WilesTests/Features/SmartFolders/SpotlightQueryTests.swift`
(usa `NSMetadataQuery` real).

**Causa raiz:** dependem de subsistemas reais do macOS sem nenhum gancho de
conclusão exposto para o processo de teste.

**Correção proposta:** para `SystemAppearanceObserverTests`, dá pra trocar o polling
por `NotificationCenter.notifications(named:)` (async sequence moderna) — ganho
pequeno, só de clareza/determinismo, não de tempo real (a notificação já é quase
instantânea). Para `SpotlightQueryTests`, não há alternativa razoável: `NSMetadataQuery`
não tem outra forma de aguardar resultado que não seja observar sua notificação
(polling-com-timeout é o padrão até fora desta codebase para testar isso).

**Ganho para o usuário: nenhum** nos dois casos.

**Estimativa:**
- tempo_atual: nenhuma das duas aparece na lista de suítes lentas (>1s) — já são rápidas
- % redução: marginal (<10%)
- custo: Baixo para a primeira, Alto (na prática, não vale a pena) para a segunda
- **ROI: ~10%** — baixa prioridade, não pelo custo, mas porque o ganho já é pequeno

---

## Categoria 4 — Janelas de debounce/timer fixas no código de produção

**Arquivos (via constantes de produção, ~11 arquivos de teste afetados):**
`Tests/WilesTests/Services/AutoOrganizationTests.swift` (janela de 2s),
`LocalHttpServerServiceTests.swift`, `LocalHttpServerServiceSecurityTests.swift`,
`Tests/WilesTests/Services/HttpServerTests.swift`,
`ThumbnailServiceCoverageTests.swift`, `FileMetadataTooltipServiceTests.swift`,
`Tests/WilesTests/FileSystem/ArchiveInspectionCancellationTests.swift`,
`Tests/WilesTests/Services/CancellableWorkTests.swift`,
`Tests/WilesTests/Models/AppState/Stores/FavoritesStoreResolvedPathsTests.swift`.

**Causa raiz:** o próprio comportamento sendo testado é "o app espera um timer/janela
de tempo antes de agir" (ex.: `AutoOrganizationService.fileStabilityWindow = .seconds(2)`
em `Sources/Wiles/Services/AutoOrganizationService.swift:20`). Isso exige tempo real
passando, a menos que o timer seja injetável.

**Correção proposta:** dar ao valor hardcoded um seam de override só para teste —
exatamente o padrão que já existe em `LocalHttpServerService.requestHeadDeadlineOverride`
nesta mesma codebase. Produção continua com 2s reais; teste roda com, por exemplo, 50ms.

**Ganho para o usuário: nenhum.** O valor de produção não muda — só o teste passa a
usar um valor menor via a variável de override.

**Estimativa (caso concreto já identificado, `fileStabilityWindow`):**
- tempo_atual: ~7–8s dentro dos 30.2s de `testAutoOrganizationTests` (3 sleeps reais
  de 2.5s/2.6s/2.8s encontrados diretamente ligados à janela de 2s)
- tempo_pos_fix: ~0.3–0.5s (janela de teste de ~50-100ms × múltiplos casos)
- % redução: ~93–95% da fatia ligada a essa janela específica
- custo: Baixo (1 ponto) — propriedade `var` + parâmetro de init opcional, mesmo padrão
  já usado no projeto
- risco: Baixo — muda só o teste, comportamento de produção idêntico
- **ROI: ~90%** (segunda melhor, atrás só da Categoria 1 por afetar uma suíte só em
  vez de várias)

*Os outros arquivos desta categoria (HTTP server deadline, thumbnail cache eviction,
etc.) têm o mesmo padrão de causa, mas cada um exigiria seu próprio override — analisado
caso a caso teria ROI parecido (~70-90%), mas não vieram medidos individualmente aqui.*

---

## Resumo — prioridade sugerida

| Categoria | Ganho usuário final | % redução tempo espera | Custo | Risco | ROI |
|---|---|---|---|---|---|
| 1. AppState + `Task.detached` | Nenhum | ~85-90% | Baixo | Baixo | **100%** |
| 4. `fileStabilityWindow` (e similares) | Nenhum | ~93-95% (por constante) | Baixo | Baixo | **90%** |
| 2. FSEvents (`withCheckedContinuation`) | Nenhum | ~40-50% | Médio | Médio | **35%** |
| 3. Notificações/Spotlight do SO | Nenhum | <10% | Baixo/Alto | Baixo | **10%** |

## Regra de decisão do usuário (2026-09-15) e veredito final

Critério dado pelo usuário: *"se for só pro teste e for só um `return` — ok. Se for só
pro teste e for uma mudança grande — não vejo por quê. Se for uma mudança grande mas
melhora muito pro usuário — aí sim vale considerar."*

Aplicando isso às 4 categorias, nenhuma delas tem ganho para o usuário final (confirmado
acima), então a decisão vira puramente sobre tamanho da mudança:

- **Categoria 1 (AppState + `Task.detached`) — FAZER.** Mudança pequena: um
  `@discardableResult` no retorno de cada método, sem tocar em lógica. Só pro teste, mas
  é exatamente o caso "é só um return, ok" — a Wiles original continua disparando e
  esquecendo exatamente como antes; o teste é que passa a ter uma alça pra segurar.
- **Categoria 4 (`fileStabilityWindow` e similares) — REVERTIDO, PROIBIDO.** Regra
  adicional dada pelo usuário depois de eu já ter implementado e revertido: **nunca**
  alterar/sobrescrever um valor de produção (janela de tempo, debounce, timeout) só pra
  o teste rodar mais rápido — mesmo com um seam "test-only" que não muda o valor real em
  produção. O teste tem que rodar contra o comportamento real do Wiles (a janela de 2s
  de verdade), porque é exatamente isso que ele existe pra verificar; usar um valor
  encurtado deixaria de testar o comportamento real. Isto também questiona o precedente
  já existente `LocalHttpServerService.requestHeadDeadlineOverride` — não removido aqui
  (não foi pedido), mas sinalizado: mesmo padrão, mesma objeção, se o usuário quiser
  revisitar.
- **Categoria 2 (FSEvents com `withCheckedContinuation`) — NÃO FAZER por ora.** Custo
  Médio (não é "só um return"), zero ganho pro usuário, e risco de continuation
  mal-fechada travando o teste. Não passa no critério.
- **Categoria 3 (Notificações/Spotlight do SO) — NÃO FAZER.** Ganho de tempo já é
  marginal (<10%) mesmo antes de considerar custo; não vale o esforço em nenhum cenário.

**Próximo passo:** implementar só a categoria 1 — deve cortar ~4-6s do tempo total da
suíte de unit tests (hoje ~109s), sem qualquer mudança de comportamento real do Wiles.
`testAutoOrganizationTests` continua em ~30s, rodando contra a janela real de 2s.
