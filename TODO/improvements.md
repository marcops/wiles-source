OK - Duplo clique não funciona em lista e  coluna
OK - Ctrl c + ctrl V deveria criar cópia não está criando
OK - Não esta traduzido regras de organização automática
OK - com o botao direito abre o menu servicoes, so ele tem icone, tira. para ficarem todos iguais 
OK - alguns itens do menu do botao direito do mouse nao estao traduzidos.
OK - Tirar o visualizador de disco do menu do mouse
ok - o mostrar etiquetas tem que estar no settings dentro da configuracao do sidebar, bem como no menu do sidebar, ele tem que ter mostrar ou nao tags.
OK - Ao mover para lixeira o cursos não seleciona o botão de excluir ou cancelar  para excluir
ok -  Na lista se eu excluir 1 arquivo ou no comum View - quero o efeito suave de subindo igual o Finder.
OK - Na busca ter opção de selecionar somente na pasta ou em todo usuário
ok -  Na pré visualização ao invés de mostrar o ícone  deve mostrar no PDF/txt a 1ªpag , no jpeg ou png como ja temos parcial nas view
ok- Lixeira nao esta abrindo esta so colocando .trash

ok -  se eu seleciono o tema claro ou escuro no settings ele muda tudo , mas se eu estou no tema branco e meu mac e tema escuro e eu seleciono sistema, ele muda o settings mas a janela que esta atras nao, so se eu seleciono escuro ou branco, o system nao muda

Ajustar a descricaoo no help. Esta referenciando o gnome, tem que ser melhor igual ao readme que ajustamos com MARKETING. ou melhor ajustar o readme publico tambem que paramos no meio, todos eles devem trazer que somos um explorer unico bem polido que era o que faltava no mac, etc e nao referenciar os outros somos melhores que eles todos.
E o sobre tambem.
ou seja ajustar sobre, readme publico e o help


Na propriedades da pasta/arquivo se o tema e escuro, no meio tem que ser fundo escuto tambem como nosso padrao e nao claro como esta


scroll nao funciona nas propriedades do arquivo com o mouse (mover para cima e para baixo) e nem no shortcut view dentro do menu help -> atalhos revisa todas as telas se nao tem este mesmo problema, e antes de arrumar avisa quais tem e precisa arrumar


Adicionar na configuração, de quanto em quanto tempo o aplicar regras vai rodar. - no settings.
Revisar se eh uma thread separada.


no gridview ajustar para 2 linha se o texto for grande e se for muito grande fica o inicio 3 pontos e o resto do texto do final ou seja mesma quantidade de caracter no inicio e final  e 3 pontos no meio, o icone nao pode mexer ou seja a aparencia tem que ser a mesma com texto pequeno de 1 linha ou de 2.
este comportamento tem que ser para todos ou seja, se eu estiver na lista e nao tem espaco para o nome inteiro tem que calcular e mostrar inicio 3 pontos e o fim.
mesma coisa para o column view

igual no IFINDER

Adiciona isto como um item no settings, visualizacao de texto ou algo assim estilo xxxx, nao sei acha um nome bom 
default e igual ao ifinder


PENDENCIAS



no localhttpserverService, extrair o HTML
    private func serveDirectoryListing(folder: URL, connection: NWConnection) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            var html = "<html><head><title>Wiles - Shared Folder</title>"
            html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'></head>"
            html += "<body style='font-family: system-ui; max-width: 800px; margin: 0 auto; padding: 20px;'>"
            html += "<h1>Shared: \(folder.lastPathComponent)</h1><hr/><ul>"
            for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let name = url.lastPathComponent
                let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
                html += "<li style='margin-bottom: 8px;'><a href=\"/\(encoded)\" style='text-decoration: none; color: #0066cc;'>\(name)</a></li>"
            }
            html += "</ul></body></html>"
            sendResponse(connection: connection, statusCode: HTTPStatus.ok, body: Data(html.utf8), contentType: "text/html")
        } catch {
            sendResponse(connection: connection, statusCode: HTTPStatus.internalServerError, body: Data("Error reading directory".utf8))
        }
    }





se seria clicar 2x no texto ou 
Se der duplo clique espaçado  (1s de delay entre eles ate 3s) fazer renome


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