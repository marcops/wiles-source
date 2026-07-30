# 🚀 Wiles: Roadmap & Lista de 55 Melhorias do File Manager

Este documento reúne um levantamento completo de **55 ideias, melhorias e novas funcionalidades** para o **Wiles** (Gerenciador de Arquivos nativo para macOS). As sugestões estão organizadas por categorias estratégicas, desde recursos essenciais de gerenciamento de arquivos até otimizações avançadas de produtividade e UI/UX.

---

## ⭐️ Categoria 1: Funcionalidades Essenciais & Padrão
*Recursos fundamentais esperados em gerenciadores de arquivos modernos.*

1. **Navegação por Abas (Multi-Tab Navigation)**: Suporte a abas na mesma janela (estilo Safari/Finder) para alternar rapidamente entre pastas sem poluir a tela.
2. **Exibição em Colunas (Miller Columns)**: Visualização em colunas encadeadas clássica do macOS para navegação hierárquica rápida em pastas profundas.
3. **Ordenação Completa de Arquivos**: Suporte nativo para ordenar por Nome, Data de Modificação, Tamanho, Tipo e Tags nas visões de Grade (Grid) e Lista.
4. **Slider de Tamanho de Ícones**: Controle deslizante no footer/toolbar para redimensionar dinamicamente as miniaturas no Grid View.
5. **Desfazer / Refazer Nativo (`Cmd+Z` / `Cmd+Shift+Z`)**: Capacidade de desfazer operações de arquivo (mover, copiar, renomear, deletar).
6. **Gerenciador de Operações em Segundo Plano**: Janela flutuante ou popover no footer exibindo progresso de cópias/transferências com opção de pausar e cancelar.
7. **Suporte Nativo a Tags do macOS**: Visualizar, adicionar e remover tags coloridas do Finder nos arquivos e pastas.
8. **Sidebar com Favoritos Editáveis (Drag-and-Drop)**: Permitir arrastar e soltar qualquer pasta para fixá-la na seção "FAVORITES" da barra lateral.
9. **Criar Novo Arquivo no Menu de Contexto**: Opção no botão direito para criar arquivos vazios instantaneamente (`.txt`, `.md`, `.swift`, `.json`).
10. **Gerenciamento Nativo da Lixeira**: Botão para esvaziar lixeira e visualização/restauração de itens contidos nela.
11. **Ejeção Nativa de Discos e DMGs**: Botão de ejeção ao lado de pendrives, HDs externos e volumes montados na barra lateral.
12. **Conectar a Servidor (SMB / AFP / NFS / FTP)**: Modal nativo para conectar e montar volumes de rede.
13. **Integração com Serviços do macOS**: Acesso aos "Serviços" do sistema no menu de contexto (Shortcuts, Automator, Quick Actions).
14. **Layouts de Exibição por Pasta**: Memorizar o modo de exibição (Grade ou Lista) individualmente para cada diretório.

---

## ⚡️ Categoria 2: Produtividade & Workflow Avançado
*Recursos projetados para desenvolvedores e power users ganharem velocidade extrema.*

15. **Modo Painel Duplo (Commander Style)**: Dois painéis independentes lado a lado para transferências rápidas acionadas via teclado.
16. **Terminal Integrado (Drawer/Panel)**: Terminal embutido expansível na parte inferior sincronizado com o diretório atual (`pwd`).
17. **Busca Avançada com Regex e Spotlight**: Integração profunda com Spotlight e suporte a Expressões Regulares no campo de busca.
18. **Pastas Inteligentes (Smart Folders)**: Salvar consultas de busca complexas como atalhos virtuais na sidebar.
19. **Integração com Git Status**: Indicadores visuais nos arquivos/pastas exibindo status do Git (Modificado, Não Rasteado, Ignorado).
20. **Atalhos Rápidos "Abrir No..."**: Botões diretos para abrir a pasta atual no VSCode, Cursor, Xcode ou Terminal nativo.
21. **Criador GUI de Symlinks**: Criar links simbólicos (`ln -s`) absolutos e relativos via interface, além dos aliases nativos do macOS.
22. **Suporte Expandido a Compactação (`.7z`, `.rar`, `.tar.gz`)**: Suporte a descompactação e leitura de múltiplos formatos de arquivo.
23. **Calculadora e Verificador de Checksum / Hash**: Aba de propriedades para calcular hashes MD5, SHA1 e SHA256 com cópia rápida.
24. **Divisor e Junção de Arquivos (File Splitter / Joiner)**: Dividir arquivos grandes em partes menores para envio e reconstituí-los.
25. **Manter Pastas Sempre no Topo**: Configuração para que pastas sempre apareçam antes de arquivos ao aplicar ordenações.
26. **Modos de Cópia de Caminho**: Botão direito com opções de copiar caminho como Absoluto, Relativo, URI (`file://`) ou Escapado para Terminal.
27. **Visualizador Rápido de Markdown e Código**: Renderização de markdown e sintaxe destacada no painel de preview lateral.

---

## 🎨 Categoria 3: Design, UI & Personalização Nativa
*Melhorias estéticas e de experiência que elevam o app ao padrão Apple Premium.*

28. **Barra de Ferramentas Personalizável**: Interface de arrastar e soltar para adicionar, remover ou reordenar itens da Toolbar.
29. **Ícones e Cores Customizadas em Pastas**: Personalizar a cor da pasta ou definir um Emoji exclusivo como ícone de diretório.
30. **Sobrescrita da Cor de Destaque (Accent Color)**: Opção de escolher uma cor de destaque personalizada independente do sistema.
31. **Modo de Densidade Compacta**: Toggle para diminuir padding e altura das linhas em telas menores de MacBooks.
32. **Mapeador de Atalhos de Teclado**: Painel nas preferências para customizar todos os atalhos de teclado da aplicação.
33. **Editor de Menu de Contexto**: Ocultar itens não utilizados do menu de clique com o botão direito para máxima rapidez.
34. **Planos de Fundo Customizados por Pasta**: Definir imagem ou marca d'água de fundo para diretórios específicos.
35. **Translucidez Adaptativa Dinâmica**: Efeitos vibrantes de translucidez (Glassmorphism nativo AppKit/SwiftUI) ajustáveis por horário ou tema.

---

## ☁️ Categoria 4: Redes, Nuvem e Conectividade
*Conexão transparente entre arquivos locais, servidores remotos e nuvem.*

36. **Navegador SFTP / SSH Nativo**: Conectar e navegar em servidores Linux remotos diretamente no Wiles.
37. **Integração Nativa com Buckets S3 / R2 / MinIO**: Gerenciador de arquivos para armazenamento em nuvem S3.
38. **Envio Rápido via AirDrop**: Ação de menu de contexto e toolbar para disparar AirDrop nativo do arquivo selecionado.
39. **Indicadores de Status de Nuvem**: Badges para iCloud, Google Drive e Dropbox mostrando estado de sincronização.
40. **Descoberta de Rede Local (Bonjour)**: Lista automática de computadores e servidores disponíveis na rede local na sidebar.
41. **Compartilhamento Rápido via HTTP Local**: Clique com botão direito em uma pasta para subir um mini servidor HTTP local e compartilhar via IP.

---

## 🔥 Categoria 5: Recursos Power User & Funcionalidades Únicas
*Recursos diferenciados que tornam o Wiles único e indispensável.*

42. **Visualizador Hexadecimal Integrado (Hex Viewer)**: Aba no painel lateral de preview para inspecionar arquivos binários em hexadecimal.
43. **Batch Renamer com Captura Regex**: Expansão do renomeador em lote com suporte a grupos de captura Regex (`$1, $2`).
44. **Visualizador Interativo de Espaço em Disco (Treemap / Sunburst)**: Gráfico interativo estilo DaisyDisk para analisar uso de espaço em disco.
45. **Exclusão Segura (File Shredder)**: Sobrescrever dados com zeros antes de deletar, ignorando a lixeira para arquivos sensíveis.
46. **Criador de RAM Disk**: Montar instantaneamente uma porção da memória RAM como disco virtual ultra rápido.
47. **Prateleira de Arquivos (Drop Stack / Shelf)**: Zona flutuante temporária para juntar arquivos de diferentes pastas antes de movê-los.
48. **Regras de Auto-Organização**: Regras automáticas em pastas (ex: "Mover todos os PDFs para Documentos").
49. **Bloqueio de Arquivos (Lock / Unlock Flag)**: Alternar a flag nativa `uchg` (imutável) do UNIX para proteger arquivos contra modificações.
50. **Comparador de Diretórios (Folder Diff)**: Selecionar duas pastas e destacar diferenças, arquivos ausentes ou atualizados.
51. **Editor de Metadados de Mídia**: Editar tags ID3 de MP3s ou EXIF de fotos diretamente no painel de Propriedades.
52. **Desinstalador de Aplicativos**: Ao deletar um `.app`, buscar e remover automaticamente arquivos órfãos de cache e preferências na `Library`.
53. **Sistema de Plugins por Scripts**: API para criar ações no menu de contexto com scripts Swift / Shell / Python.
54. **Exibição Plana (Flat View)**: Exibir todos os arquivos contidos em subpastas em uma única lista plana contínua.
55. **Modo Privado / Furtivo (Ghost Mode)**: Desativar gravação de arquivos `.DS_Store` e histórico recente durante a navegação.
