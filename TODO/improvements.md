O RENAME tem que ser direto na view e nao em uma modal.
o gridview tem que mostrar 2 linhas igual o ifinder


teste intermitente (falha às vezes, não relacionado a nenhuma mudança - reproduzido isolado 2026-08-08): AutoOrganization — alterna entre falhar em
"POS: Rule routes matching .pdf file to destination" e "POS: a real matching file alongside the dotfile is still moved correctly".
Parece timing (o teste espera o tamanho do arquivo parar de mudar / debounce antes de mover). Rever amanhã.


bug grave, parou de pegar eu digitando, tanto na busca quando no nova pasta, o que eu fiz a principio foi abrir a busca para digitar e fiz resize depois disso nao pegou mais eu digitando nada na busca, nao consigo gitira rmais na busca


### `ArchiveInspectionService.swift:35` — `readDataToEndOfFile()` buffers subprocess stdout in one shot
**Priority: Low** — archive *listings* are small text output even for large archives; the risk
is theoretical unless someone opens an archive with an enormous entry count.
**Complexity: Moderate** — would need a streaming reader instead of a one-shot read; not worth
it unless it's an actual reported problem. Note: as of 2026-08-08, `listEntries` no longer shells
out to `unzip`/`Process` at all (it parses the ZIP central directory directly via
`ZIPCentralDirectoryReader` — see `ArchiveInspectionService.swift`'s `listEntries`), so this
specific line/finding may already be stale; only `extractSingleEntry` still uses `Process`, and
its `try process.run()` is already non-silent (not what this finding was about). Re-verify line
numbers before picking this up.