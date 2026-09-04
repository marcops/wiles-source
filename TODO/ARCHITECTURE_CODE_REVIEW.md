# Architecture & Code Review

Revisão completa de código-fonte (arquitetura, código, concorrência, SwiftUI, UX/produto), gerada incrementalmente arquivo por arquivo. Ver `TODO/eval/eval.md` para os critérios completos.

**Escopo**: 215 de 289 arquivos `.swift` em `Sources/Wiles` (75 arquivos triviais listados em `TODO/eval/IGNORAR.md` foram pulados; `Tests/` está fora do escopo por definição). Nota: `Services/FileTemplate.swift`, listado em `IGNORAR.md`, não existe mais na árvore — entrada obsoleta.

**Status — Cobertura final**: revisão completa, **duas rodadas**. Rodada 1: **215/215 arquivos no escopo revisados, linha por linha** (95 por este agente — Constants, Models incl. AppState, Services incl. FileSystem; 120 por um segundo agente em paralelo — Features, Views, App). Total rodada 1: **13 findings principais** (todos corrigidos, testados e removidos desta lista), 3 itens em NOT WORTH, 2 findings completos na seção "skipped by comments", 5 regras de engenharia sugeridas, 2 regras de lint propostas (uma verificada contra os 215 arquivos, 124 ocorrências reais confirmadas, zero falsos positivos), 15 candidatos a `IGNORAR.md`, nenhum flicker novo. Rodada 2 (dois agentes em paralelo, mesmo split de escopo, rodada contra o código já corrigido pela rodada 1): confirmou que as correções da rodada 1 se sustentam e não introduziram regressão; encontrou **6 findings novos**, todos corrigidos/testados/compilados e portanto já removidos desta lista (MB-202 — corrida de navegação superando `runSmartFolder`; MU-095 — drop de arrastar-e-soltar/breadcrumb sem barra de progresso nem cancelamento; mais 4 em `BatchRenameService`/`IntegratedTerminalView`/`FolderPickerNodeView` cobrindo a mesma classe de bug de R6/R7 num arquivo que a rodada 1 não tinha tocado), e propôs 2 extensões de wording para R6/R7 (adotadas em `.agents/DEV_RULES.md`).

---

## Findings by ID

<!-- Findings principais (CRITICAL/HIGH/MEDIUM/LOW/SUGGESTION que passam no Safety Gate + filtro ROI) são adicionados aqui, em ordem de descoberta. -->

## NOT WORTH

<!-- Uma linha por item, apenas após passar pelo Safety Gate. -->

[LL-056] `Views/Components/ScrollerAutoHideSetter.swift` e `SplitViewDividerSetter.swift` duplicam um padrão idêntico de ~30 linhas de "NSView applier com gate hasApplied" (ambos se referenciam explicitamente em comentários como espelhos intencionais) — ROI 0.56.
[SL-072] `PersistablePreferenceStore.keysToEvict` claims to evict the pre-existing baseline before the just-added batch, but within that baseline it picks an arbitrary `Set`-iteration-order subset (not real insertion/recency order) — affects `SidebarPreferences.expandedTreePaths` and `ViewPreferences.perFolderViewModes` (contrast with `BoundedFolderNodeCache`, which does track real insertion order correctly) — ROI 0.72, cosmetic/self-healing only.

## Flickers

Nenhum flicker novo identificado nas 215 arquivos revisados. `PaginatedItemsSection` e `ShortcutsHUDOverlay` carregam comentários documentando bugs de flicker JÁ CORRIGIDOS anteriormente (remoção de `.animation` em nível de coleção que causava reflow completo da grid; unificação de `.clipShape` no background do card para corrigir corner-radius renderizando incompatível entre estados) — ambos já resolvidos, não são findings novos.

## Findings skipped by comments in the source code

<!-- Findings completos (com todas as propriedades) que só não viraram ação porque há um comentário no código justificando/ressalvando o comportamento. -->

### [LL-024] `RepositionerView`'s `ObjectIdentifier`-keyed cache é teoricamente vulnerável a reuso de ponteiro entre janelas
- ROI: 0.24 (seria NOT WORTH, mas reportado por inteiro pela regra desta seção — quase foi ignorado por causa dos comentários extensos que já justificam o design)
- LOW / EDGE CASE / comportamento potencialmente incorreto, mas auto-corrigível
- Confidence: LOW CONFIDENCE
- Arquivo: `Views/Header/RepositionerView.swift`
- Símbolo: `private static var lastAppliedX: [BaselineKey: CGFloat]`, `reposition()`
- Problema: `BaselineKey` é indexado por `ObjectIdentifier(button)`/`ObjectIdentifier(superview)`. Uma vez que uma janela (e seus `NSButton`s de traffic-light) é desalocada, uma janela criada em seguida poderia, em princípio, alocar seus próprios botões no mesmo endereço de memória, produzindo um `ObjectIdentifier` idêntico e fazendo `reposition()` ler uma baseline obsoleta calculada para o botão de uma janela não relacionada.
- Por que quase foi ignorado: os comentários ao redor explicam e justificam extensivamente toda a estratégia de cache ("self-heals on the very next pass", limitado por `maxBaselineEntries`, "harmless if this fires for some other window") — o design lê como cuidadoso e testado, o que tornou fácil aceitá-lo à primeira vista em vez de investigar especificamente o ângulo de reuso de identidade.
- Impacto: mesmo no cenário de colisão, o próprio princípio de design do código (se não está onde esperávamos, recalcula a partir dele imediatamente) significa que o pior caso é um deslocamento visual de um único frame dos botões de traffic-light, autocorrigido no próximo `layout()`/resize.
- Solução sugerida: nenhuma estritamente necessária dada a propriedade auto-corretiva; se perseguida, substituir a chave `ObjectIdentifier` por um token explicitamente invalidado no fechamento da janela.
- Complexidade: baixa, se perseguida.
- ROI factors: Impacto 5, Redução de risco 10, Manutenção 10, Performance 0, Simplicidade 5, Esforço 15, Risco da mudança 10.

### [HM-050] Hardcoded fine-grained GitHub PAT in `CrashReportingConstants.githubToken`
- ROI: 0.50 — mantido aqui apenas por completude (regra do eval.md: item quase ignorado por causa de comentário no código deve ser listado por inteiro nesta seção).
- HIGH / SECURITY (hardcoded secret) — mas ACEITO EXPLICITAMENTE pelo projeto, não é uma ação pendente.
- Confidence: CONFIRMED
- Arquivo: `Constants/CrashReportingConstants.swift`
- Símbolo: `CrashReportingConstants.githubToken`
- Problema: o token (fine-grained PAT, escopo `Issues: Read and write` apenas no repo `marcops/wiles`) está hardcoded no binário e é extraível de qualquer build distribuído.
- Por que normalmente seria um problema: qualquer pessoa com o `.app` consegue extrair o token e abrir/ler/comentar issues no repo em nome da automação de crash-report.
- Por que NÃO foi levantado como ação: o próprio arquivo já documenta a decisão (comentário datado de 2026-08-30, finding B1-1): sem conta Apple Developer paga, não há mecanismo de signing/provisioning do Xcode para injetar segredos em builds de release distribuídas — hardcoded é a única forma de o app shipped conseguir reportar crashes. O comentário pede explicitamente para não "consertar" isso e não reabrir a discussão.
- Impacto real (dado o aceite): limitado — token de escopo único (issues do próprio repo público), não credencial de conta/organização.
- Solução sugerida (não recomendada para execução agora, apenas registrada): um proxy server-side removeria a exposição, caso a restrição de custo/conta mude no futuro.
- Complexidade: N/A (decisão de produto, não bug de código).
- ROI factors: Impacto 30, Redução de risco 20, Manutenção UNKNOWN, Performance 0, Simplicidade 0, Esforço UNKNOWN, Risco da mudança UNKNOWN.

## Suggested New Engineering Rules

Todas as 5 regras sugeridas nesta rodada foram adotadas e já vivem nos arquivos de regras permanentes do projeto (não repetidas aqui):
- `.agents/DEV_RULES.md` — "A Fallible Staging Step Must Be Inside the Recovery Scope of the Operation It Stages For" (R6), "A Cancellable Batch Operation Must Preserve and Finalize Partial Results Already Committed Before Cancellation" (R7), "A Function Whose Completion Timing Varies by Input Needs an Explicit, Awaitable Completion Contract".
- `.agents/SWIFT_LANG_RULES.md` — "Independent Per-Row Async Actions Must Not Share One Cancellation Token".

## Suggested Lint Rules

A regra sugerida nesta rodada ("No Review Finding ID in Production Comments") foi implementada como `no_finding_id_in_comment` em `.swiftlint.yml`, e as 128 ocorrências pré-existentes no código-fonte foram limpas. Verificado: `swiftlint lint --strict` → 0 violations; `swift build` → build limpo.

## NOTA DO PROJETO

**Global**: esta é uma base de código incomumente madura para o tamanho (215 arquivos revisados, ~21.700 linhas na metade Constants/Models/Services sozinha). Praticamente todo arquivo carrega comentários referenciando findings de revisões anteriores já corrigidos (BA-108, HH-089, MM-070, MM-161, LL-144, ML-090, ML-102, ML-120, ML-139, MM-096, MM-104, MM-121, MM-150, R1–R5, e dezenas de outros) — as classes de bug "óbvias" (force-unwrap, task não-cancelável, `enumerator` sem `errorHandler`, retain cycle, digitação insegura de path) já foram varridas e corrigidas sistematicamente. Os 13 findings principais desta rodada quase todos exigiram traçar uma SEQUÊNCIA entre componentes (navegação assíncrona vs. síncrona, staging vs. bloco de recuperação, um `@State` de cancelamento compartilhado entre linhas de UI) em vez de um bug isolado numa função — exatamente o tipo de descoberta que `eval.md` pediu, e um sinal de que revisões futuras devem continuar priorizando rastreamento de sequência sobre inspeção função-por-função.

**Arquitetura**: a separação `AppState` → domain stores (`navigation`/`selection`/`fileSystem`/`preferences`/`modal`/`smartFolder`) → `Services` (stateless ou singletons per-window) é consistente e bem respeitada nas duas metades revisadas. A distinção per-window vs. compartilhado (`WindowUIState` vs. stores compartilhados) é aplicada corretamente em todo lugar verificado. O único padrão arquitetural genuinamente frágil encontrado é o contrato assíncrono inconsistente de `AppState.navigateTo` (síncrono para caminhos locais, fire-and-forget para `/Volumes/`) — não é overengineering nem uma decisão errada por si só, mas um contrato implícito que já produziu dois bugs reais (HH-398, MM-098) e deveria ganhar uma forma explícita e aguardável.

**Código**: a qualidade é alta e uniforme — sem sinais de overengineering, abstrações desnecessárias, ou complexidade não justificada em nenhuma das 215 arquivos. O achado de maior escala não é um bug de lógica, mas um problema de higiene: 124 referências a IDs de finding de revisão (`(MM-078)`, `(LL-020)`, etc.) embutidas em comentários de produção, violando uma regra já explícita do projeto — mecanicamente corrigível com uma limpeza + a regra de lint proposta.

**Concorrência**: também uniformemente forte — `Task.detached` + `withTaskCancellationHandler` corretos, `NSLock`/`actor`-like disciplina em caches compartilhados, staleness tokens em operações assíncronas de longa duração. As exceções encontradas (HH-409, HH-306: leitura síncrona de disco no `@MainActor` para um caminho potencialmente `/Volumes/`; MM-208: leitura de `listener` fora de `queue.sync`) são notáveis justamente por serem exceções a um padrão que o resto do código aplica com rigor — sugerem que vale uma varredura pontual squad-wide por outras leituras síncronas de disco em código `@MainActor` que não seja um "Service" dedicado (onde a atenção a isso é mais natural), já que os dois casos encontrados estavam em `AppState`/`UndoRedoService`, não em um `FileSystemService`.

**Produto/UX**: nenhuma lacuna de produto significativa encontrada além dos bugs já listados. O padrão "configurar em um sheet, disparar a operação, fechar imediatamente, reportar via o canal de background-operations" é consistente entre BatchRename/ImageConverter/PDF-merge/DuplicateCleaner.

