OK - Duplo clique não funciona em lista e  coluna
OK - Ctrl c + ctrl V deveria criar cópia não está criando
OK - Não esta traduzido regras de organização automática
OK - com o botao direito abre o menu servicoes, so ele tem icone, tira. para ficarem todos iguais 
OK - alguns itens do menu do botao direito do mouse nao estao traduzidos.
OK - Tirar o visualizador de disco do menu do mouse


#pendente
o mostrar etiquetas tem que estar no settings dentro da configuracao do sidebar, bem como no menu, ele tem que ter mostrar ou nao tags.

Ao mover para lixeira o cursos não seleciona o botão de excluir ou cancelar  para excluir

Na lista se eu excluir 1 arquivo ou no comum View - quero o efeito suave de subindo igual o Finder.

Na propriedades da pasta/arquivo tirar scroll e fundo preto padrão

Se der duplo clique espaçado fazer renome

Na busca ter opção de selecionar somente na pasta ou em todo usuário

jpeg com e não esta gerando imagem thumbmail

Ver quando roda as regras de. Moer o arquivo

Na pré visualização ao invés de mostrar o ícone  deve mostrar no PDF/txt a 1ªpag , no jpeg ou png a imagem

Lixeira nao esta abrindo esta so colocando .trash

Ajustar a descreio no help. Esta referenciando o gnome, tem que ser melhor igual ao readme que ajustamos com MARKETING.
E o sobre

Adicionar na configuração, de quanto em quanto tempo o aplicar regras vai rodar. - no settings.
Revisar se eh uma thread separada.


scroll nao funciona nas propriedades do arquivo com o mouse (mover para cima e para baixo) e nem no shortcut view dentro do menu help -> atalhos revisa todas as telas se nao tem este mesmo problema, e antes de arrumar avisa quais tem e precisa arrumar


bug grave, parou de pegar eu digitando, tanto na busca quando no nova pasta, o que eu fiz a principio foi abrir a busca para digitar e fiz resize depois disso nao pegou mais eu digitando nada na busca, nao consigo gitira rmais na busca


no localhttpserverService, estrair o HTML
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

teste intermitente (falha às vezes, não relacionado a nenhuma mudança - reproduzido isolado 2026-08-08): AutoOrganization — alterna entre falhar em
"POS: Rule routes matching .pdf file to destination" e "POS: a real matching file alongside the dotfile is still moved correctly".
Parece timing (o teste espera o tamanho do arquivo parar de mudar / debounce antes de mover). Rever amanhã.

no localhttpserverService, estrair o HTML