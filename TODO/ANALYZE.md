# Análise do projeto (2026-08-21)

Itens 1-8 da auditoria original (estado compartilhado entre janelas em `UndoRedoService`/`TerminalViewCache`, `AppState` init desperdiçando I/O, textos hardcoded, falha silenciosa no paste de clipboard, condicionais compostas inline, campo morto no `TransientStore`) já foram corrigidos — build limpo, 97/97 testes passando. Duas regras novas de lint (`no_inline_compound_condition`, `no_hardcoded_swiftui_text`) foram adicionadas ao `.swiftlint.yml` pra evitar recorrência.

Deliberadamente adiados (baixo valor / alto custo de churn no momento):

- **Limpeza de comentários longos** — ~110 blocos de comentário no código passam de 4+ linhas, acima do limite de 1-2 linhas do `GENERAL_RULES.md` (ex: `WindowUIState.swift`, `AppState.swift`). Bulk-edit arriscado sem revisão caso a caso.
- **Drift estrutural cosmético** — `searchQuery`/`isSearching`/`selectedURLs` ainda vivem direto em `AppState.swift` em vez de um store próprio, inconsistente com a convenção documentada de "nova propriedade vai no domain store". Inofensivo hoje (AppState já é per-window), não urgente.
