Quero uma revisão dedicada exclusivamente a bugs de RENDERIZAÇÃO/VISUAL — não
arquitetura, não lógica de negócio, não concorrência de dados. `eval.md` já
cobre isso. Este documento existe porque `eval.md` sozinho comprovadamente NÃO
pega uma classe inteira de bug: código cuja LÓGICA está certa mas cujo efeito
visual na tela está errado (ex.: scrollbar da sidebar que nunca aparece depois
que a directory tree é expandida — `LazyVStack` recursivo dentro de um único
`ScrollView` ancestral quebrando o recálculo de geometria do `NSScrollView`).

Motivo de existir um documento separado, não apenas mais uma seção em
`eval.md`: revisão de arquitetura lê o código e pergunta "a lógica está
certa?". Revisão de renderização lê o código e pergunta uma coisa
fundamentalmente diferente — "quando ESTE valor muda, o que EXATAMENTE
recalcula a tela, e QUANDO?" — e boa parte dos findings aqui só podem ser
CONFIRMADOS rodando o app de verdade (`xcodebuild test` com um `WilesUITests`
real), não só lendo texto. As duas óticas exigem checklist e metodologia
diferentes; misturá-las faz a de renderização virar um item esquecido no meio
de uma lista de 900 linhas sobre outra coisa.

## Escopo

- Todo arquivo em `Sources/Wiles/Views/**/*.swift`.
- Todo `NSViewRepresentable`/`NSViewControllerRepresentable` em qualquer
  pasta (ex.: `ScrollerAutoHideSetter`, `SplitViewDividerSetter`,
  `TranslucentVisualEffectView`).
- Todo `ViewModifier` custom que afeta aparência/scroll/animação
  (`.translucentBackground`, `.resetPaginationAndPrefetchThumbnails`, etc.).
- Qualquer `@State`/`@Binding`/`@Observable` propriedade que alimenta
  diretamente um desses arquivos, mesmo que a própria propriedade viva em
  `Models/AppState/`.
- NÃO revise lógica de negócio, filesystem, concorrência de dados ou
  persistência aqui — isso é `eval.md`. Se um finding for realmente sobre
  lógica (não sobre o que aparece na tela), registre-o para `eval.md` em vez
  de forçá-lo aqui.

## Watchers / Eventos Recorrentes (TEMPORÁRIO — pertence a `eval.md`, não é bug de render)

Regra estacionada aqui a pedido do usuário; mover para a seção "Eventos de
Alta Frequência" de `eval.md` quando houver oportunidade. Não é escopo deste
documento (é lógica/concorrência, não render) — registrada aqui só para não
se perder.

Motivação: um bug real (sidebar/main content presos em "loading" para
sempre) passou por várias rodadas de `eval.md` sem ser pego. A seção
"Eventos de Alta Frequência" já existia e já nomeava o padrão certo
("watchers", "coalescing", "eventos antigos processados quando o resultado
já não é relevante"), mas o finding foi descartado porque a evidência
("o load demora mais que o intervalo entre eventos") parecia depender de uma
condição de runtime não demonstrável em código — exatamente o tipo de coisa
que "Evidência e Confiança" rebaixa para MEDIUM/LOW confidence, e que depois
o filtro de ROI descarta.

Regra nova: promova para CONFIRMED (não precisa de repro em runtime) todo
caso em que TODAS as condições abaixo são verificáveis por leitura de
código:

1. Existe uma fonte de evento recorrente e externa (FSEvents/watcher,
   `NSNotification`, timer, mensagem de rede) que dispara uma função de
   refresh/reload.
2. Essa função faz cancel-and-restart da operação anterior (`task?.cancel()`
   seguido de um novo `Task { }`) em vez de deixar a operação em andamento
   terminar.
3. O custo da operação cancelada escala com um fator externo sem limite
   superior conhecido (contagem de arquivos, tamanho de resposta de rede,
   etc.) — ou seja, não há garantia de que ela sempre termine mais rápido
   que o intervalo entre eventos.
4. Não existe, no CONSUMIDOR do evento (não no produtor), nenhum mecanismo
   que só deixe uma nova tentativa substituir a anterior se a anterior já
   tiver terminado (um debounce/coalescing do lado do PRODUTOR do evento,
   por si só, não conta — ele limita a taxa de disparo, não impede que o
   disparo seguinte cancele um trabalho ainda em andamento).

Quando as 4 condições valem, isso é um livelock estrutural — não uma
hipótese — mesmo sem uma pasta real grande/barulhenta à mão para reproduzir.
O caso confirmado neste projeto: `DirectoryMonitor` (FSEvents) →
`AppState.startDirectoryMonitoring`'s callback → `refreshCurrentDirectory`
→ `fileSystem.refreshTask?.cancel()` + novo `Task`, com o custo de
`FileItem.load`/`resolveHighResIcon` escalando com o número de arquivos da
pasta. Corrigido com uma flag `isRefreshing` no consumidor: um evento que
chega enquanto uma refresh já está rodando é descartado (não cancela),
garantindo que pelo menos uma tentativa sempre chega ao fim. Teste de
regressão: `AppStateDirectoryRefreshTests.testDirectoryListingCompletesUnderContinuousExternalWritePressure`.

## O que procurar

Para cada View, trace explicitamente:

`Valor/estado que muda → quem observa esse valor → o que especificamente
recalcula na tela → QUANDO isso recalcula (mesmo frame? próximo layout pass?
só na remontagem completa?) → o resultado visual final está correto?`

Isso é o "teste de mesa de renderização": não basta confirmar que o dado
mudou — tem que confirmar que o WIDGET certo, na hora certa, reagiu a essa
mudança. Um dado correto com um widget que não recalcula na hora certa
produz exatamente o tipo de bug que uma revisão de lógica nunca vê.

### Padrões estaticamente reconhecíveis como red flag

Estes são verificáveis por leitura de código, sem precisar rodar o app —
tratá-los como suspeitos automáticos, não como prova de bug:

- **`LazyVStack`/`LazyHStack` recursivo**: uma View que se auto-referencia
  (`Self(...)`) e usa `LazyVStack` internamente, aninhando múltiplas
  instâncias dentro de UM `ScrollView` ancestral compartilhado. Cada nível
  de recursão é uma aposta sobre o `ScrollView` recalcular corretamente o
  tamanho total quando um nível profundo muda de tamanho — muitas vezes não
  recalcula. Prefira `VStack` simples nesse padrão, a menos que o número de
  itens por nível seja genuinamente grande (centenas+).
- **Conteúdo assíncrono chegando depois do layout inicial** (`.task`,
  `Task {}`, callback) que escreve em `@State`/cache consumido por um
  `ScrollView`/`Lazy*Stack`. Pergunte: o container pai recalcula tamanho
  quando isso chega, ou só na próxima remontagem completa da View?
- **`NSViewRepresentable` que localiza um `NSView` específico andando pela
  hierarquia** (`superview`/`subviews`) para estilizá-lo — ex.: forçar
  `scrollerStyle`, achar o `NSScrollView` real por baixo de um `ScrollView`
  SwiftUI. Nunca aceite o comentário do próprio código como prova de que
  funciona; é código não-verificável estaticamente por definição. Um gate
  tipo `hasApplied` que nunca reaplica depois que a hierarquia muda de
  tamanho é sinal concreto de que a instância encontrada pode ficar
  obsoleta assim que o conteúdo cresce.
- **Modificador de aparência aplicado no nível errado da árvore**
  (`.scrollIndicators`, `.animation`, `.clipShape`, `.mask`,
  `.background`) — compare onde o comentário do código diz que o efeito
  deveria aparecer versus em qual View exatamente o modificador está
  anexado. `.background()` em particular cria ambiguidade sobre se a View
  resultante é IRMÃ do conteúdo real ou fica ANINHADA dentro dele — a
  diferença muda completamente que hierarquia AppKit resulta daquilo.
- **`GeometryReader`/`ScrollViewReader` proxy usado depois que o valor que
  originou aquele frame já mudou** — proxies capturados em closures
  assíncronas podem estar obsoletos no momento em que são usados.
- **`@State` local vs. referência compartilhada (`class`) usada como
  "cache" atrás de várias Views** — se uma é `@State` (SwiftUI observa) e
  a outra é uma referência plana compartilhada (SwiftUI não observa), qual
  delas dispara o re-render real importa exatamente para ONDE e QUANDO a
  tela atualiza. Ver `BoundedFolderNodeCache`'s doc comment para o caso já
  corrigido no projeto.
- **`.id()` trocando identidade da View** — força remontagem completa
  (perde `@State`, reseta scroll position, reseta animação em andamento).
  Verifique se isso é intencional ou um efeito colateral não percebido.
- **Propriedade de um `NSView`/`NSScrollView` do AppKit setada só UMA VEZ
  (gate tipo `hasApplied`/`hasAppliedStyle`), quando essa propriedade é uma
  que o PRÓPRIO AppKit também reatribui em runtime por conta própria** —
  ex.: `NSScrollView.scrollerStyle`, que o macOS recalcula sozinho conforme
  o dispositivo de entrada (mouse físico vs. trackpad) sob "Show scroll
  bars: Automatically based on mouse or trackpad", **sem nenhum aviso ao
  app**. Um código que força esse valor uma vez no mount e nunca mais
  reforça está numa corrida contra o próprio AppKit — quem "ganha" por
  último (o app, no mount, ou o sistema, a qualquer scroll futuro) decide o
  comportamento, e o sistema sempre ganha depois do primeiro scroll real.
  Isso não aparece como `isHidden == true` nem como erro nenhum — o
  `NSScroller` continua existindo e "não escondido" segundo o próprio
  AppKit, só fica desenhado atrás do conteúdo (que não abriu espaço para o
  estilo `.legacy` que substituiu o `.overlay`). Caso confirmado neste
  projeto: `ScrollerAutoHideSetter` forçava `scrollerStyle = .overlay`
  apenas uma vez; um mouse wheel real fazia o macOS trocar para `.legacy`
  e nunca mais voltava — nem trocando outras seções da sidebar. Corrigido
  reforçando o valor em TODA chamada (`layout()`/`updateNSView`) e também
  diretamente nos observers de `NSScrollView.willStartLiveScrollNotification`/
  `didLiveScrollNotification`/`didEndLiveScrollNotification` (o
  `layout()`/`updateNSView` da View sozinho não necessariamente dispara
  durante um gesto de scroll puro). Teste de regressão:
  `ScrollerAutoHideSetterTests.testKeepOverlayStyleRevertsLegacyStyleBackToOverlay`.
  Generalizando: sempre que um valor for tanto setado pelo app QUANTO
  recalculado autonomamente pelo framework em resposta a um evento de
  sistema (não só scroller — outros candidatos: `NSWindow.appearance`,
  `NSApplication` sob mudança de tema, `NSTextView` sob spell-check
  automático), um gate de "aplicar uma vez" é insuficiente por definição —
  precisa reforçar continuamente ou observar o evento de sistema relevante
  e reagir a ele.

### Metodologia: um finding aqui tem duas fases obrigatórias

1. **Suspeita estática** — encontrar o padrão de risco acima, registrar
   como candidato.
2. **Confirmação em runtime** — TODO candidato que descreve um efeito
   visual (aparece/some, anima errado, não recalcula tamanho) precisa de
   uma confirmação real, não apenas leitura de código:
   - Escreva um teste em `Tests/WilesUITests/` usando `XCUIApplication`
     que reproduza o cenário (ex.: expandir a árvore até haver overflow,
     depois `app.scrollBars.firstMatch.waitForExistence(timeout:)`).
   - Rode com:
     `xcodebuild test -scheme Wiles -destination 'platform=macOS' -only-testing:WilesUITests/<Suite>`
     (NÃO `swift test` — SPM não produz bundle de UI testing; `validate.sh`
     roda isso separadamente, ver `WilesLaunchUITests.swift`'s cabeçalho).
   - Confirme que o teste FALHA no código atual (prova que o bug é real e
     que o teste de fato o detecta) antes de aplicar a correção, depois
     confirme que PASSA depois da correção.
   - Se não for possível escrever um teste automatizado razoável para um
     candidato específico (ex.: comportamento que depende de preferência
     de sistema do usuário), diga isso explicitamente no finding e marque
     como "requer verificação manual" em vez de fingir que foi confirmado.
   Um finding sem nenhuma das duas confirmações acima é uma SUSPEITA, não
   um finding — reporte-o como tal (seção própria, não junto dos
   confirmados).

## Testes de lógica (o que ainda cabe em unit test aqui)

Bugs de renderização pura não são alcançáveis por unit test (XCTest não
observa pixels/NSScroller). Mas a LÓGICA que alimenta o render às vezes é
testável isoladamente — e DEVE ganhar um unit test quando for:

- Semântica de referência vs. valor de um cache/estado compartilhado entre
  Views (ex.: `BoundedFolderNodeCacheTests.testReferenceSemanticsShare-
  MutationsAcrossHolders`) — prova a PROPRIEDADE de que o bug de fan-out
  dependia, sem precisar renderizar nada.
- Funções puras que computam o que vai para a tela (formatação, ordenação,
  filtragem, geometria calculada manualmente) — não a renderização em si.
- Condições de guarda que decidem SE algo deveria re-renderizar (ex.: "só
  aplica se `expandedPaths.contains(url)`") — teste a condição isolada da
  View.

Não force um unit test para o que só é observável correndo o app de
verdade — isso produz um teste que sempre passa e não prova nada (falso
senso de segurança), que é pior do que admitir "isto precisa de UI test".

## Classificação, ROI, Safety Gate, formato de finding

Reaproveite integralmente o esquema de `eval.md`: IDs `[Severidade][Impacto]-
[ROIx100]`, fórmula de ROI, Safety Gate, seção NOT WORTH, seção "Findings
skipped by comments". Não duplique aqui — a única diferença é o ESCOPO
(render, não arquitetura) e a EXIGÊNCIA extra de confirmação em runtime
descrita acima.

## Resultado final

Gere/atualize `TODO/RENDER_CODE_REVIEW.md`, incrementalmente, seguindo a
mesma disciplina de `TODO/ARCHITECTURE_CODE_REVIEW.md` (apagar findings do
arquivo assim que corrigidos e testados — não marcar como done). Cada
finding confirmado deve linkar o teste de UI que o comprova (caminho do
arquivo + nome do método de teste).
