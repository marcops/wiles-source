Quero uma revisão arquitetural e de código COMPLETA do projeto.

IMPORTANTE:
- Analise APENAS arquivos de código-fonte.
- NÃO analise testes, arquivos de teste, mocks de teste ou código exclusivamente relacionado a testes.
- Pule todos os arquivos listados em `IGNORAR.md`.
- Não faça uma revisão superficial ou apenas por amostragem.
- Revise linha a linha os arquivos de código relevantes.
- Não altere o código durante esta etapa. Apenas analise e gere o relatório.
- Ao final, gere um `TODO/ARCHITECTURE_CODE_REVIEW.md`` dentro da pasta `TODO`.

Nunca considere a revisão concluída enquanto 100% dos arquivos de código relevantes não tiverem sido analisados.

## Objetivo

Quero uma revisão feita como se você fosse simultaneamente:

1. Senior/Staff Swift Engineer
2. Software Architect
3. Especialista em arquitetura e design patterns
4. Especialista em Swift/SwiftUI e performance
5. UI/UX Engineer
6. Product Engineer

Não quero que você simplesmente valide se o código atual está "bom".

Quero que você tente DESCOBRIR problemas e oportunidades que eu ainda não percebi.

A arquitetura atual é uma arquitetura própria do projeto. Ela deve ser respeitada como contexto, mas NÃO deve ser considerada correta simplesmente porque já foi adotada.

Se você acreditar que alguma decisão arquitetural atual está errada, excessivamente complexa, difícil de manter ou inadequada para o produto, diga explicitamente.

## O que procurar

Analise, entre outras coisas:

### Código

- DRY
- KISS
- SOLID quando realmente aplicável
- Clean Code
- responsabilidades mal distribuídas
- abstrações desnecessárias
- duplicação
- código excessivamente complexo
- métodos/classes grandes demais
- acoplamento desnecessário
- dependências desnecessárias
- estado duplicado
- lógica espalhada
- condições que poderiam ser simplificadas
- APIs internas inconsistentes
- naming
- tipos inadequados
- force unwraps / force casts
- tratamento de erros
- edge cases
- estados impossíveis ou inconsistentes
- race conditions
- problemas de concorrência
- memory management
- retain cycles
- lifecycle issues
- Swift Concurrency
- MainActor
- Sendable
- async/await
- performance
- allocations desnecessárias
- trabalho repetido
- operações que poderiam ser lazy
- operações de I/O desnecessárias
- problemas de escalabilidade

### Arquitetura

Verifique criticamente:

- separação de responsabilidades
- boundaries entre componentes
- dependências
- direção das dependências
- acoplamento
- coesão
- extensibilidade
- testabilidade estrutural (SEM analisar os testes)
- gerenciamento de estado
- persistência
- comunicação entre componentes
- eventos
- serviços
- stores
- models
- views
- view models
- protocolos
- abstrações
- composição
- lifecycle
- isolamento de features

Avalie também se patterns como:

- Strategy
- Factory
- Adapter
- Coordinator
- Observer
- Repository
- Command
- State
- Dependency Injection
- etc.

seriam úteis.

MAS NÃO introduza design patterns apenas porque eles existem.

Um pattern só deve ser sugerido quando resolver um problema real.

# Análise de Sequências e Máquina de Estados

Não analise apenas funções isoladamente.

Quando uma operação depende de múltiplas funções ou componentes, trace a
sequência completa.

Exemplos:

View → Store → Service → filesystem
View → Process manager → Process → termination callback
Preflight → Executor → Rollback
User input → parser → URL → filesystem
Watcher → debounce → reload → UI
Shared service → View lifecycle → resource

Para cada sequência, procure inconsistências entre os estados assumidos por
cada camada.

Verifique especialmente:

- quem pode chamar a operação;
- em qual estado ela pode ser chamada;
- o que acontece se for chamada duas vezes;
- o que acontece se for chamada durante outra operação;
- o que acontece se falhar;
- o que acontece se for cancelada;
- o que acontece se o owner desaparecer;
- se callbacks podem chegar depois do encerramento;
- se o estado final realmente corresponde ao resultado da operação.

Um finding pode estar na interação entre componentes mesmo que cada
componente isoladamente pareça correto.


Depois da análise local de cada arquivo, faça também análise transversal
entre os componentes relacionados.

Não considere uma função correta apenas porque sua implementação local parece
correta.

Trace seus callers, callees, estado compartilhado, lifecycle e efeitos
colaterais quando isso for necessário para determinar seu comportamento real.


## EVITE OVERENGINEERING

Esta é uma regra PRINCIPAL da revisão.

Não quero transformar código simples em uma arquitetura complexa apenas para seguir princípios teóricos.

Sempre questione:

- Essa abstração realmente reduz complexidade?
- Esse protocolo realmente é necessário?
- Essa camada realmente agrega valor?
- Essa classe precisa existir?
- Esse pattern resolve um problema real?
- Estamos criando infraestrutura para um problema que ainda não existe?
- O código poderia ser significativamente mais simples?
- Estamos abstraindo algo que provavelmente nunca terá outra implementação?
- Estamos criando indireção demais?
- Estamos sacrificando legibilidade para ganhar flexibilidade hipotética?

Se a solução atual for simples e correta, NÃO sugira mudança apenas porque existe uma arquitetura "mais sofisticada".

Quero otimizar para:

    simplicidade
    + corretude
    + manutenção
    + baixo acoplamento
    + baixo risco de bugs
    + performance
    + evolução futura

e NÃO para:

    quantidade de abstrações
    + quantidade de protocolos
    + quantidade de patterns
    + arquitetura por arquitetura

OU SEJA
    se algo for complexo e tem como tornar simples avise, a busca e por menos linhas, menos codigo, mais simplicidade, menos bug, menos ifs e corner cases.

## Quero descobertas, não apenas validação

Procure ativamente por coisas como:

- bugs que ainda não foram percebidos
- comportamentos incorretos em edge cases
- estados que podem ficar inconsistentes
- caminhos que podem causar crashes
- race conditions
- problemas de lifecycle
- memory leaks
- problemas de performance
- código que funciona hoje mas provavelmente quebrará com evolução do produto
- decisões que dificultarão futuras features
- pontos onde uma pequena mudança agora evitará uma grande mudança depois
- responsabilidades que deveriam estar em outro lugar
- código que pode ser removido
- código que pode ser consolidado
- código que pode ser simplificado
- abstrações que podem desaparecer
- componentes que podem ser combinados
- componentes que deveriam ser separados
- dependências que podem ser eliminadas
- lógica que deveria estar centralizada
- lógica que NÃO deveria estar centralizada
- inconsistências entre features
- convenções que não estão sendo seguidas
- oportunidades de padronização
código aparentemente morto;
APIs sem consumidores;
abstrações sem múltiplas implementações;
propriedades sem necessidade;
branches inalcançáveis.


No swift

public desnecessário;
internal vs private;
protocols expostos sem necessidade;
tipos que vazam abstrações de implementação.
@State
@StateObject
@ObservedObject
@Environment
@EnvironmentObject
@Bindable
identity das views
body recomputation
reference types dentro de value views
derived state
view lifecycle.

## Produto / negócio

Também analise o código do ponto de vista de Produto.

Procure decisões técnicas que possam dificultar:

- futuras funcionalidades
- evolução do produto
- mudanças de UX
- mudanças de comportamento
- configuração
- escalabilidade funcional
- suporte a novos casos de uso

Se encontrar algo que faça sentido preparar agora por razões de negócio, indique.

Porém:

NÃO implemente ou recomende antecipadamente infraestrutura para funcionalidades hipotéticas sem justificativa concreta.

Não registre diferenças puramente estilísticas como findings, salvo quando afetarem consistência, legibilidade, manutenção ou risco.

Diferencie claramente:

- problema atual
- melhoria preventiva
- preparação razoável para o futuro
- overengineering


# Controle de Findings Duplicados

Se o mesmo problema aparecer em vários arquivos:
- determine se existe uma causa arquitetural comum;

Um finding deve existir porque existe impacto em pelo menos um destes:

- corretude;
- risco;
- manutenção;
- complexidade;
- performance;
- lifecycle;
- arquitetura;
- UX/produto;
- evolução do sistema.

Se o benefício for puramente subjetivo, não registre.

## Evidência e Confiança

Não registre como BUG um comportamento apenas hipotético.

Para cada finding, determine o nível de evidência:

- CONFIRMED — o código demonstra diretamente o problema;
- HIGH CONFIDENCE — o comportamento é consequência clara do fluxo analisado;
- MEDIUM CONFIDENCE — depende de uma condição específica não totalmente
  demonstrável no código;
- LOW CONFIDENCE — hipótese que merece investigação adicional.

Findings LOW CONFIDENCE não devem receber severidade alta nem ROI elevado.

Quando possível, descreva o caminho de execução que demonstra o problema.

## Tracing de Dependências

Quando necessário para confirmar um finding, trace:

- callers;
- callees;
- referências ao símbolo;
- mutations do estado;
- lifecycle;
- owners;
- callbacks;
- delegates;
- publishers/subscribers;
- notificações;
- tasks relacionadas.

Não faça tracing indiscriminado de todo o projeto para cada símbolo.

Expanda a análise apenas quando necessário para entender o comportamento ou
confirmar o impacto de um finding.

## UI / UX

Analise também:

- estados de loading
- empty states
- error states
- feedback visual
- estados inconsistentes
- comportamento inesperado
- ações destrutivas
- confirmações
- affordances
- navegação
- acessibilidade
- consistência
- comportamento de sheets/dialogs
- feedback após operações
- UX de erros
- UX de operações longas
- estados impossíveis de UI

Procure problemas que possam não ser óbvios apenas olhando para a arquitetura.
Quero descobertas, não apenas validação

## Invariantes

Para componentes que possuem estado significativo, identifique seus
invariantes.

Exemplos:

- se A existe, B também deve existir;
- se uma operação está `running`, existe exatamente um owner;
- se o preflight aprovou uma operação, o executor deve conseguir executá-la;
- se um recurso está `active`, seu lifecycle owner ainda deve existir;
- se uma View observa determinado estado, esse estado deve representar a
  fonte de verdade correspondente.

Procure caminhos capazes de quebrar esses invariantes.

Quando um finding depender de um invariante, descreva explicitamente:

`Invariante → caminho que o quebra → estado resultante → impacto`.

## Idempotência e Operações Repetidas

Para operações de lifecycle, persistência, filesystem, network e state
management, verifique:

- o que acontece se a operação for chamada duas vezes;
- se `start()` pode ser chamado duas vezes;
- se `stop()` pode ser chamado antes de `start()`;
- se `cancel()` pode ser chamado duas vezes;
- se uma operação concluída pode ser repetida;
- se callbacks podem chegar duplicados;
- se retries podem executar efeitos colaterais novamente.

Identifique operações que deveriam ser idempotentes mas não são.

## Cancellation

Para todo código assíncrono relevante, analise:

- propagação de `Task` cancellation;
- `Task.isCancelled` / `checkCancellation()`;
- tasks órfãs;
- detached tasks;
- operações que continuam após a View desaparecer;
- callbacks depois do cancelamento;
- cleanup após cancelamento;
- tasks duplicadas;
- possibilidade de operações concorrentes sobre o mesmo recurso.

Não considere uma operação cancelável apenas porque retorna `Task` ou usa
`async/await`.

Verifique se o cancelamento realmente interrompe ou invalida o trabalho.

## Eventos de Alta Frequência

Para watchers, notifications, keyboard events, scroll, drag, typing e outras
fontes de eventos frequentes, analise:

- debounce;
- throttle;
- coalescing;
- deduplicação;
- filas;
- backpressure;
- trabalho redundante;
- eventos obsoletos;
- processamento no MainActor.

Verifique se eventos antigos continuam sendo processados quando seu resultado
já não é relevante.

Procure especialmente por pipelines onde:

`evento → state mutation → render → trabalho`

é executado repetidamente quando poderia ser coalescido.

## Simplificação e Redução de Código

Procure ativamente oportunidades para remover complexidade.

Considere:

- eliminar abstrações;
- remover protocolos desnecessários;
- eliminar wrappers;
- combinar tipos que não possuem responsabilidade independente;
- remover estados redundantes;
- substituir state machines desnecessárias por tipos/enum simples;
- eliminar branches redundantes;
- substituir pipelines excessivamente indiretos por chamadas diretas;
- remover configuração duplicada;
- reduzir número de layers;
- remover código morto;
- centralizar somente quando isso realmente reduzir duplicação;
- substituir mecanismos customizados por APIs nativas quando isso reduzir
  complexidade.

Para cada proposta de simplificação, estime também:

- linhas/camadas potencialmente removíveis;
- número de componentes afetados;
- risco da mudança;
- se a simplificação reduz ou apenas desloca complexidade.

Não proponha simplificação se ela apenas mover a complexidade para outro
lugar.

## Complexity Budget

Ao avaliar uma abstração, considere a complexidade total introduzida:

- quantidade de tipos;
- quantidade de protocolos;
- quantidade de layers;
- quantidade de indirection;
- quantidade de state;
- quantidade de lifecycle;
- quantidade de branches;
- quantidade de pontos de configuração.

Uma solução que reduz duplicação mas aumenta significativamente a complexidade
estrutural deve ser avaliada criticamente.

Prefira a solução com menor complexidade total que preserve corretude,
manutenção e evolução.

## Minha arquitetura atual

Não assuma que minha arquitetura está correta.

Use-a como contexto.

Se encontrar algo que você acredita que deveria ser diferente:

1. explique o problema;
2. explique por que a arquitetura atual não é ideal;
3. explique a alternativa;
4. explique o custo/migração;
5. diga se vale fazer agora ou posteriormente.

Não faça uma reescrita arquitetural simplesmente por preferência pessoal.

## Novas regras

Não se limite às regras acima.

Se durante a revisão você identificar uma regra de engenharia que deveria existir no projeto, apresente-a como:

SUGESTÃO DE NOVA REGRA

Explique:

- qual é a regra;
- qual problema ela evita;
- exemplos encontrados no projeto;
- se deveria virar guideline, code review rule ou lint rule.

## LINT

Ao final, faça uma análise específica procurando oportunidades de automatização.

Verifique se alguma das descobertas pode virar uma regra de Lint.

Para cada candidato, informe:

- regra proposta;
- problema que ela evita;
- exemplo do código atual;
- se é possível detectar automaticamente;
- se deveria ser Regex, SwiftLint custom rule ou outra abordagem;
- risco de falsos positivos;
- benefício esperado.

Se houver uma regra simples que possa ser implementada por Regex e que seja realmente útil, proponha-a.

NÃO crie regras de lint apenas por criar.

Se tiver algum que pode gerar falso positivo NAO Queremos
OU SEJA NAO QUEREMOS HEURISTICOS QUE PODEM DAR FALSO POSITIVO. TEM QUE SER 100% ASSERTIVO

## IGNORAR.md

Existem arquivos em `IGNORAR.md` que são deliberadamente simples e não precisam ser avaliados.

Pule esses arquivos.

Durante a revisão, se encontrar outros arquivos que claramente não precisam de revisão futura porque são triviais, repetitivos, gerados ou não agregam valor arquitetural, sugira adicioná-los ao `IGNORAR.md`.

Não adicione automaticamente sem justificar no relatório.

## Classificação das descobertas

Para cada problema encontrado, classifique:

CRITICAL (C)
- pode causar bugs graves, corrupção de estado, crashes, perda de dados ou problemas arquiteturais importantes.

HIGH (H)
- problema importante que deveria ser corrigido.

MEDIUM (M)
- melhoria relevante de arquitetura, manutenção, performance ou qualidade.

LOW (L)
- melhoria pequena ou de qualidade.

SUGGESTION (S)
- ideia futura, melhoria opcional ou possível evolução.

ARCHITECTURAL CONCERN (A)
- decisão estrutural que merece reconsideração.

OVERENGINEERING (O)
- abstração, complexidade ou arquitetura que poderia ser simplificada.

BUG (B)
- comportamento potencialmente incorreto.

PERFORMANCE (P)
- oportunidade concreta de melhorar performance.

PRODUCT/UX (U)
- problema ou oportunidade relacionada à experiência ou ao produto.


## Custo × Benefício / ROI

Para cada melhoria sugerida, estime:

- Impacto: 0–100
- Redução de risco: 0–100
- Benefício de manutenção: 0–100
- Benefício de performance: 0–100
- Benefício de simplicidade: 0–100
- Esforço: 0–100
- Risco da mudança: 0–100

Calcule:

VALUE =
(Impacto × 0.30) +
(Redução de risco × 0.25) +
(Benefício de manutenção × 0.20) +
(Benefício de performance × 0.10) +
(Benefício de simplicidade × 0.15)

COST =
(Esforço × 0.70) +
(Risco da mudança × 0.30)

ROI = VALUE / COST


Quando não houver evidência suficiente para estimar algum fator, marque como
"UNKNOWN" em vez de inventar precisão.

A estimativa deve ser baseada no impacto concreto observado no código, e não
na quantidade de princípios ou regras violadas.

Não recomende uma melhoria apenas porque ela é tecnicamente correta.
A melhoria deve apresentar benefício proporcional ao custo e risco da alteração.


## Para cada descoberta

Inclua:

- Severidade
- Categoria
- Arquivo
- símbolo/método/classe relevante
- problema
- por que é um problema
- impacto
- solução sugerida
- complexidade da correção
- ROI

Quando possível, inclua uma pequena explicação do código envolvido.

Não faça sugestões vagas como "melhorar arquitetura".

Quero saber EXATAMENTE:

"o que está errado"
→ "por que está errado"
→ "o que fazer"
→ "qual benefício isso traz"


## Resultado final

Crie um relatório em:

`TODO/ARCHITECTURE_CODE_REVIEW.md`

O relatório deve conter pelo menos:

# Architecture & Code Review

## Findings by ID

ID deve ser composto por severidade, impacto  e ROI
ou seja BA-127 (roi *100=) (bug alto 1,27)
ou SM-089 (sugestion medium 0,89)
ou por exemplo
OU CL-290 (critical low 2,9)

**## Finding ID**

Cada finding deve receber um ID no formato:

`[SEVERITY][IMPACT]-[ROI × 100]`

Onde:

Severity:
- C = Critical
- H = High
- M = Medium
- L = Low
- S = Suggestion

Impact:
- C = Critical
- H = High
- M = Medium
- L = Low

Exemplos:

- `CH-290` = Critical severity / High impact / ROI 2.90
- `HM-142` = High severity / Medium impact / ROI 1.42
- `SL-085` = Suggestion severity / Low impact / ROI 0.85

O ROI deve ser arredondado para duas casas decimais e multiplicado por 100
para formar o sufixo numérico do ID.

O ID deve permanecer estável durante a revisão, mesmo que a ordem dos findings mude.

FIcando os findings POR EXEMPLO

### [SL-242] Duplicação de `ThumbnailService.maxDimension` e `FileItem.highResIconSize`
- ROI: 2.42 (Forte candidato)
- LOW / DRY / magic number
- Arquivos: `Services/ThumbnailService.swift`, `Models/FileItem.swift`
- Problema: o mesmo valor e propósito estão definidos em dois lugares.
- Solução: centralizar em um único token compartilhado.
- Complexidade: baixa.

# NOT WORTH
[SL-085] LOW / DRY — duplicação de X em A.swift e B.swift — ROI 0.85.
[SM-062] MEDIUM / SIMPLIFICATION — X poderia ser simplificado — ROI 0.62.

O FILTRO do NOT WORTH e:

LOW, SUGESTION, COSMETIC,UI UX,  + ROI < 1.00 → NOT WORTH
MEDIUM + ROI < 0.70 → NOT WORTH
Todas as demais descobertas permanecem na lista principal.

Os itens em NOT WORTH devem ser resumidos em UMA ÚNICA LINHA cada.
OU SEJA NAO FICAM COMPLETOS NO FINDINGS ID

Não incluir os detalhes completos desses itens.
Não criar seções adicionais, consolidações ou agrupamentos além de NOT WORTH.

# NOT WORTH — REGRA ESTRITA DE DESCARTE

`NOT WORTH` NÃO significa "ROI baixo, portanto ignorar".

Antes de colocar QUALQUER finding em `NOT WORTH`, faça obrigatoriamente esta
verificação:

### 1. Safety Gate

Se o finding envolver QUALQUER um dos itens abaixo, ele NÃO PODE ser colocado
em `NOT WORTH`, independentemente do ROI:

- corrupção de dados;
- perda de dados;
- perda de estado persistido;
- crash;
- resource leak;
- process leak;
- infinite loop;
- deadlock;
- race condition;
- security issue;
- comportamento incorreto observável pelo usuário;
- operação que pode falhar depois de ter sido declarada válida;
- estado inconsistente;
- filesystem corruption;
- arquivo temporário órfão após crash/falha;
- operação de Undo/Redo que pode não reverter corretamente;
- lifecycle incorreto;
- callback após owner/resource ter sido encerrado;
- operação que pode deixar recursos ou estado em condição inválida.

A presença de qualquer desses problemas OVERRIDE o filtro de ROI.

### 2. Somente depois aplicar o filtro de ROI

Depois da Safety Gate:

- LOW + ROI < 1.00 → `NOT WORTH`
- MEDIUM + ROI < 0.70 → `NOT WORTH`

Todos os demais permanecem em `Findings by ID`.

### 3. Não classificar incorretamente o tipo do problema

Não classifique como `PERFORMANCE`, `COSMETIC`, `DRY` ou `EDGE CASE`
um finding cujo efeito final seja:

- operação incorreta;
- estado inconsistente;
- perda de dados;
- falha de Undo;
- filesystem inconsistente;
- lifecycle incorreto.

Classifique pelo IMPACTO REAL do comportamento.

Exemplo:

`crash durante operação → arquivo temporário fica órfão`

NÃO é apenas:

`LOW / EDGE`

É:

`LOW / BUG / filesystem recovery`

Outro exemplo:

`trashItem não retorna URL → Undo recebe URL incorreta → Undo falha`

NÃO é apenas:

`LOW / EDGE`

É:

`LOW / BUG / UX`

Outro exemplo:

`sanitizer aceita nome <= 255 Characters → filesystem rejeita > 255 bytes`

NÃO é apenas:

`LOW / PERFORMANCE`

É:

`LOW / BUG / filesystem`

### 4. Discrepância entre ROI e severidade

Quando um finding protegido pela Safety Gate tiver ROI baixo,
mantenha-o na lista principal e explique:

> ROI baixo devido à baixa frequência/probabilidade, mas não descartado
> porque o comportamento pode produzir [efeito concreto].

Nunca aumente artificialmente o ROI para justificar sua permanência.

### 5. Regra fundamental

`NOT WORTH` é reservado exclusivamente para melhorias que sejam:

- não críticas;
- não incorretas;
- não destrutivas;
- não causadoras de inconsistência;
- não relacionadas a lifecycle incorreto;
- não causadoras de leak;
- não causadoras de crash;
- não causadoras de perda de dados/estado;
- e cujo benefício não justifique o custo da correção.

Se houver dúvida entre `NOT WORTH` e `Findings by ID`,
mantenha em `not worth`.

# Disciplina de ROI

Não aumente artificialmente o ROI porque um problema é tecnicamente
interessante.

Um finding de performance só deve receber alto benefício de performance se
houver um caminho de execução plausivelmente frequente ou custoso.

Um finding de edge case só deve receber alto impacto se o código demonstrar
que o estado pode realmente ocorrer.

Se o impacto, frequência ou custo forem incertos, use UNKNOWN.

Não use princípios arquiteturais isoladamente como justificativa para elevar
Impacto ou Redução de risco.

## Suggested New Engineering Rules

## Suggested Lint Rules

## Files That Could Be Added to IGNORAR.md

## NOTA DO PROJETO

E quero uma nota para o projeto:
Global
arquitetura
codigo
produto
e algum outro que ache que faz sentido


# REGRA FINAL

Não quero uma revisão complacente.

Não presuma que o código está correto porque ele compila.

Não presuma que a arquitetura está correta porque foi projetada deliberadamente.

Não introduza complexidade sem benefício real.

Não procure apenas violações de regras.

Procure também aquilo que NÃO está explicitamente proibido, mas que poderia ser melhor.

O objetivo é encontrar problemas que um desenvolvedor normalmente não perceberia em uma revisão superficial e deixar o projeto:

- mais simples
- mais seguro
- mais previsível
- mais performático
- mais fácil de evoluir
- mais fácil de manter
- menos propenso a bugs

Sem overengineering.

REGRA IMPORTANTE:
NAO GERE O ARQUIVO NO FINAL; VAI FAZENDO APPEND CONFORME FOR AVALIANDO
Conforme for fazendo vai dando a % de progresso no chat
com quantos high, medium, low, etc encontrados


Se voce pensou em ignorar algum item porque ele tem comentario, coloca este finding com o item completo do finding (todas as propriedades, roi etc)
mas em uma sessao no FINAL
FINDINGS skipped by comments in the SOURCE CODE

Flickers sao graves, por iso mesmo que seja not worth, coloca eles numa lista separada so de flickers.