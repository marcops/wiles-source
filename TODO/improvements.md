O RENAME tem que ser direto na view e nao em uma modal.
o gridview tem que mostrar 2 linhas igual o ifinder


teste intermitente (falha às vezes, não relacionado a nenhuma mudança - reproduzido isolado 2026-08-08): AutoOrganization — alterna entre falhar em
"POS: Rule routes matching .pdf file to destination" e "POS: a real matching file alongside the dotfile is still moved correctly".
Parece timing (o teste espera o tamanho do arquivo parar de mudar / debounce antes de mover). Rever amanhã.


bug grave, parou de pegar eu digitando, tanto na busca quando no nova pasta, o que eu fiz a principio foi abrir a busca para digitar e fiz resize depois disso nao pegou mais eu digitando nada na busca, nao consigo gitira rmais na busca


ok - `ArchiveInspectionService.swift` readDataToEndOfFile finding confirmed stale/resolved:
`listEntries` no longer shells out at all (parses ZIP central directory directly), and
`extractSingleEntry`'s `Process` already streams stdout straight to a FileHandle on disk
(never buffers in RAM) with non-silent `try process.run()`. Nothing to fix.