Quero uma revisão arquitetural e de código COMPLETA do projeto.

IMPORTANTE:
- Abra exatamente 1 agentes apenas
- Analise APENAS arquivos de código-fonte.
- NÃO analise testes, arquivos de teste, mocks de teste ou código exclusivamente relacionado a testes.
- Pule todos os arquivos listados em `IGNORAR.md`.
- Não faça uma revisão superficial ou apenas por amostragem.
- Revise linha a linha os arquivos de código relevantes.
- Não altere o código durante esta etapa. Apenas analise e gere o relatório.
- Ao final, gere um `REPORT.md` dentro da pasta `TODO`.

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

Diferencie claramente:

- problema atual
- melhoria preventiva
- preparação razoável para o futuro
- overengineering

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

## IGNORAR.md

Existem arquivos em `IGNORAR.md` que são deliberadamente simples e não precisam ser avaliados.

Pule esses arquivos.

Durante a revisão, se encontrar outros arquivos que claramente não precisam de revisão futura porque são triviais, repetitivos, gerados ou não agregam valor arquitetural, sugira adicioná-los ao `IGNORAR.md`.

Não adicione automaticamente sem justificar no relatório.

## Classificação das descobertas

Para cada problema encontrado, classifique:

CRITICAL
- pode causar bugs graves, corrupção de estado, crashes, perda de dados ou problemas arquiteturais importantes.

HIGH
- problema importante que deveria ser corrigido.

MEDIUM
- melhoria relevante de arquitetura, manutenção, performance ou qualidade.

LOW
- melhoria pequena ou de qualidade.

SUGGESTION
- ideia futura, melhoria opcional ou possível evolução.

ARCHITECTURAL CONCERN
- decisão estrutural que merece reconsideração.

OVERENGINEERING
- abstração, complexidade ou arquitetura que poderia ser simplificada.

BUG
- comportamento potencialmente incorreto.

PERFORMANCE
- oportunidade concreta de melhorar performance.

PRODUCT/UX
- problema ou oportunidade relacionada à experiência ou ao produto.

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
- se deve ser corrigido agora ou posteriormente

Quando possível, inclua uma pequena explicação do código envolvido.

Não faça sugestões vagas como "melhorar arquitetura".

Quero saber EXATAMENTE:

"o que está errado"
→ "por que está errado"
→ "o que fazer"
→ "qual benefício isso traz"

## Priorização

Ao final, produza uma lista ordenada das melhorias por:

1. impacto
2. redução de risco
3. benefício arquitetural
4. benefício de manutenção
5. performance
6. simplicidade
7. esforço necessário

Quero saber quais mudanças realmente valem a pena fazer primeiro.

## Resultado final

Crie um relatório em:

`TODO/ARCHITECTURE_CODE_REVIEW.md`

O relatório deve conter pelo menos:

# Architecture & Code Review

## Executive Summary

## Critical Findings

## High Priority Findings

## Medium Priority Findings

## Low Priority Findings

## Bugs Discovered

## Overengineering / Simplification Opportunities

## Architecture Concerns

## DRY / KISS / SOLID Findings

## Performance Findings

## Swift / SwiftUI Findings

## UI / UX Findings

## Product / Future Evolution

## Suggested New Engineering Rules

## Suggested Lint Rules

## Files That Could Be Added to IGNORAR.md

## Recommended Roadmap

Ordene a roadmap em:

### Phase 1 — Quick Wins
### Phase 2 — Important Improvements
### Phase 3 — Architectural Improvements
### Phase 4 — Future / Optional

## REGRA FINAL

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



E quero uma nota para o projeto:
Global
arquitetura
codigo
produto
e algum outro que ache que faz sentido

REGRA IMPORTANTE:
NAO GERE O ARQUIVO NO FINAL; VAI FAZENDO APPEND CONFORME FOR AVALIANDO
NOME DO ARQUIVO O QUE ACHOU.. 
e nao considere que porque tenho regra ou esta feito de 1 maneira que esta certo, se tiver algum padrao que nao e bom revise

Conforme for fazendo vai dando a % de progresso no chat