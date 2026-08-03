# Wiles: Future Features

Native-only (no third-party libraries). Items found by auditing the codebase against what macOS/Finder already offers natively.

1. **Sempre Abrir Com (Change All)**: complemento do "Abrir Com" — permite definir o app padrão para todos os arquivos de um tipo (`.ext`), via `LSSetDefaultRoleHandlerForContentType`. Hoje só abre uma vez, não persiste como padrão.
2. **Restaurar última pasta ao reabrir**: hoje sempre inicia na Home (`AppState.swift:317-318`). Salvar `currentURL.path` em `UserDefaults` ao trocar de pasta e restaurar no init.
3. **Busca por conteúdo de arquivo**: hoje `FileSystemService.swift:22-23` só filtra por nome. Usar `NSMetadataQuery`/Spotlight (`kMDItemTextContent`) para achar arquivos pelo conteúdo, como o Finder faz em "Conteúdo do arquivo".
4. **Combinar/mesclar arquivos em PDF**: usar `PDFKit` nativo (`PDFDocument`, `insert(_:at:)`) para juntar imagens/PDFs selecionados em um único PDF, via menu de contexto.
