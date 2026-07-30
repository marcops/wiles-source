import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case english = "en"
    case portuguese = "pt"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .portuguese: return "Português"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        }
    }
}

public struct L10n {
    public static func activeCode(_ preferred: AppLanguage) -> String {
        if preferred != .system { return preferred.rawValue }
        let sys = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if sys.hasPrefix("pt") { return "pt" }
        if sys.hasPrefix("es") { return "es" }
        if sys.hasPrefix("fr") { return "fr" }
        if sys.hasPrefix("de") { return "de" }
        return "en"
    }

    public static func string(_ key: Key, lang: AppLanguage) -> String {
        let code = activeCode(lang)
        return localized[key]?[code] ?? localized[key]?["en"] ?? key.rawValue
    }

    public enum Key: String, Sendable {
        case newFolder
        case paste
        case selectAll
        case sortBy
        case viewMode
        case gridView
        case listView
        case showHiddenFiles
        case showHiddenFilesGnome
        case showHiddenFilesMac
        case hideStatusBar
        case showStatusBar
        case showFavorites
        case showMacSection
        case showRecents
        case sidebarMode
        case shortcutMode
        case refresh
        case copyPath
        case folderProperties
        case open
        case quickLook
        case removeFromFavorites
        case addToFavorites
        case cut
        case copy
        case copyContent
        case moveToTrash
        case compressToZip
        case extractHere
        case rename
        case properties
        case noResultsFound
        case folderIsEmpty
        case name
        case size
        case dateModified
        case kind
        case folder
        case favorites
        case mac
        case recents
        case devices
        case directoryTree
        case searchPlaceholder
        case home
        case desktop
        case documents
        case downloads
        case music
        case pictures
        case movies
        case trash
        case applications
        case airDrop
        case iCloudDrive
        case freeSpace
        case itemsCount
        case itemsCountWithSize
        case selectedItemsCount
        case selectedItemsCountWithSize
        case language
        case cancel
        case create
        case createNewFolder
        case folderNamePlaceholder
        case defaultFolderName
        case enterPathPlaceholder
        case root
        case ascending
        case location
        case modified
        case hidden
        case yes
        case no
        case close
        case parentFolder
        case done
        case helpShortcuts
        case batchRename
        case find
        case replaceWith
        case prefix
        case suffix
        case sequenceNumbering
        case startNumber
        case preview
        case originalName
        case newName
        case apply
        case quickConvertImage
        case targetFormat
        case resizePreset
        case cropPreset
        case quality
        case convert
        case diskUsageVisualizer
        case topLargestItems
        case aboutWiles
        case newFileTitle
        case selectTemplate
        case fileNameLabel
        case extractArchive
        case connectToServer
        case connect
        case aboutDescription
        case createdBy
        case version
        case translucentLevel
        
        case showPreviewSidebar
        case moreInfo
        case general
        case permissions
        case owner
        case group
        case created
        case lastOpened
        case dimensions
        case duration
        case fetchError
    }

    private static let localized: [Key: [String: String]] = [
        .newFolder: [
            "en": "New Folder...",
            "pt": "Nova Pasta...",
            "es": "Nueva Carpeta...",
            "fr": "Nouveau dossier...",
            "de": "Neuer Ordner..."
        ],
        .paste: [
            "en": "Paste",
            "pt": "Colar",
            "es": "Pegar",
            "fr": "Coller",
            "de": "Einfügen"
        ],
        .selectAll: [
            "en": "Select All",
            "pt": "Selecionar Tudo",
            "es": "Seleccionar Todo",
            "fr": "Tout sélectionner",
            "de": "Alles auswählen"
        ],
        .sortBy: [
            "en": "Sort By",
            "pt": "Ordenar por",
            "es": "Ordenar por",
            "fr": "Trier par",
            "de": "Sortieren nach"
        ],
        .viewMode: [
            "en": "View Mode",
            "pt": "Modo de Visualização",
            "es": "Modo de Vista",
            "fr": "Mode d'affichage",
            "de": "Ansichtsmodus"
        ],
        .gridView: [
            "en": "Grid View",
            "pt": "Visualização em Grade",
            "es": "Vista de Cuadrícula",
            "fr": "Affichage en grille",
            "de": "Rasteransicht"
        ],
        .listView: [
            "en": "List View",
            "pt": "Visualização em Lista",
            "es": "Vista de Lista",
            "fr": "Affichage en liste",
            "de": "Listenansicht"
        ],
        .showHiddenFiles: [
            "en": "Show Hidden Files",
            "pt": "Mostrar Arquivos Ocultos",
            "es": "Mostrar Archivos Ocultos",
            "fr": "Afficher les fichiers masqués",
            "de": "Ausgeblendete Dateien anzeigen"
        ],
        .showHiddenFilesGnome: [
            "en": "Show Hidden Files (Ctrl+H)",
            "pt": "Mostrar Arquivos Ocultos (Ctrl+H)",
            "es": "Mostrar Arquivos Ocultos (Ctrl+H)",
            "fr": "Afficher les fichiers masqués (Ctrl+H)",
            "de": "Ausgeblendete Dateien anzeigen (Ctrl+H)"
        ],
        .showHiddenFilesMac: [
            "en": "Show Hidden Files (Cmd+Shift+.)",
            "pt": "Mostrar Arquivos Ocultos (Cmd+Shift+.)",
            "es": "Mostrar Arquivos Ocultos (Cmd+Shift+.)",
            "fr": "Afficher les fichiers masqués (Cmd+Shift+.)",
            "de": "Ausgeblendete Dateien anzeigen (Cmd+Shift+.)"
        ],
        .hideStatusBar: [
            "en": "Hide Status Bar",
            "pt": "Ocultar Barra de Status",
            "es": "Ocultar Barra de Estado",
            "fr": "Masquer la barre d'état",
            "de": "Statusleiste ausblenden"
        ],
        .showStatusBar: [
            "en": "Show Status Bar",
            "pt": "Mostrar Barra de Status",
            "es": "Mostrar Barra de Estado",
            "fr": "Afficher la barre d'état",
            "de": "Statusleiste anzeigen"
        ],
        .showFavorites: [
            "en": "Show Favorites",
            "pt": "Mostrar Favoritos",
            "es": "Mostrar Favoritos",
            "fr": "Afficher les favoris",
            "de": "Favoriten anzeigen"
        ],
        .showMacSection: [
            "en": "Show MAC Section",
            "pt": "Mostrar Seção MAC",
            "es": "Mostrar Sección MAC",
            "fr": "Afficher la section MAC",
            "de": "MAC-Bereich anzeigen"
        ],
        .showRecents: [
            "en": "Show Recents",
            "pt": "Mostrar Recentes",
            "es": "Mostrar Recientes",
            "fr": "Afficher les récents",
            "de": "Zuletzt verwendet anzeigen"
        ],
        .sidebarMode: [
            "en": "Sidebar Mode",
            "pt": "Modo da Barra Lateral",
            "es": "Modo de Barra Lateral",
            "fr": "Mode barre latérale",
            "de": "Seitenleistenmodus"
        ],
        .shortcutMode: [
            "en": "Shortcut Mode",
            "pt": "Modo de Atalhos",
            "es": "Modo de Atajos",
            "fr": "Mode raccourcis",
            "de": "Tastenkürzel-Modus"
        ],
        .refresh: [
            "en": "Refresh",
            "pt": "Atualizar",
            "es": "Actualizar",
            "fr": "Actualiser",
            "de": "Aktualisieren"
        ],
        .copyPath: [
            "en": "Copy Path",
            "pt": "Copiar Caminho",
            "es": "Copiar Ruta",
            "fr": "Copier le chemin",
            "de": "Pfad kopieren"
        ],
        .folderProperties: [
            "en": "Folder Properties",
            "pt": "Propriedades da Pasta",
            "es": "Propiedades de la Carpeta",
            "fr": "Propriétés du dossier",
            "de": "Ordnereigenschaften"
        ],
        .open: [
            "en": "Open",
            "pt": "Abrir",
            "es": "Abrir",
            "fr": "Ouvrir",
            "de": "Öffnen"
        ],
        .quickLook: [
            "en": "Quick Look",
            "pt": "Visualização Rápida",
            "es": "Vista Rápida",
            "fr": "Aperçu rapide",
            "de": "Übersicht"
        ],
        .removeFromFavorites: [
            "en": "Remove from Favorites",
            "pt": "Remover dos Favoritos",
            "es": "Eliminar de Favoritos",
            "fr": "Retirer des favoris",
            "de": "Aus Favoriten entfernen"
        ],
        .addToFavorites: [
            "en": "Add to Favorites",
            "pt": "Adicionar aos Favoritos",
            "es": "Adicionar a Favoritos",
            "fr": "Ajouter aux favoris",
            "de": "Zu Favoriten hinzufügen"
        ],
        .cut: [
            "en": "Cut",
            "pt": "Recortar",
            "es": "Cortar",
            "fr": "Couper",
            "de": "Ausschneiden"
        ],
        .copy: [
            "en": "Copy",
            "pt": "Copiar",
            "es": "Copiar",
            "fr": "Copier",
            "de": "Kopieren"
        ],
        .copyContent: [
            "en": "Copy Content",
            "pt": "Copiar Conteúdo",
            "es": "Copiar Contenido",
            "fr": "Copier le contenu",
            "de": "Inhalt kopieren"
        ],
        .moveToTrash: [
            "en": "Move to Trash",
            "pt": "Mover para a Lixeira",
            "es": "Mover a la Papelera",
            "fr": "Placer dans la Corbeille",
            "de": "In den Papierkorb legen"
        ],
        .compressToZip: [
            "en": "Compress to ZIP",
            "pt": "Compactar para ZIP",
            "es": "Comprimir a ZIP",
            "fr": "Compresser en ZIP",
            "de": "In ZIP komprimieren"
        ],
        .extractHere: [
            "en": "Extract Archive Here",
            "pt": "Extrair Arquivo Aqui",
            "es": "Extraer Archivo Aquí",
            "fr": "Extraire l'archive ici",
            "de": "Archiv hier entpacken"
        ],
        .rename: [
            "en": "Rename...",
            "pt": "Renomear...",
            "es": "Renombrar...",
            "fr": "Renommer...",
            "de": "Umbenennen..."
        ],
        .properties: [
            "en": "Properties",
            "pt": "Propriedades",
            "es": "Propiedades",
            "fr": "Propriétés",
            "de": "Eigenschaften"
        ],
        .noResultsFound: [
            "en": "No Results Found",
            "pt": "Nenhum Resultado Encontrado",
            "es": "Sin Resultados",
            "fr": "Aucun résultat trouvé",
            "de": "Keine Ergebnisse gefunden"
        ],
        .folderIsEmpty: [
            "en": "Folder is Empty",
            "pt": "A Pasta está Vazia",
            "es": "La Carpeta está Vacía",
            "fr": "Le dossier est vide",
            "de": "Ordner ist leer"
        ],
        .name: [
            "en": "Name",
            "pt": "Nome",
            "es": "Nombre",
            "fr": "Nom",
            "de": "Name"
        ],
        .size: [
            "en": "Size",
            "pt": "Tamanho",
            "es": "Tamaño",
            "fr": "Taille",
            "de": "Größe"
        ],
        .dateModified: [
            "en": "Date Modified",
            "pt": "Data de Modificação",
            "es": "Fecha de Modificación",
            "fr": "Date de modification",
            "de": "Änderungsdatum"
        ],
        .kind: [
            "en": "Kind",
            "pt": "Tipo",
            "es": "Clase",
            "fr": "Type",
            "de": "Art"
        ],
        .folder: [
            "en": "Folder",
            "pt": "Pasta",
            "es": "Carpeta",
            "fr": "Dossier",
            "de": "Ordner"
        ],
        .favorites: [
            "en": "FAVORITES",
            "pt": "FAVORITOS",
            "es": "FAVORITOS",
            "fr": "FAVORIS",
            "de": "FAVORITEN"
        ],
        .mac: [
            "en": "MAC",
            "pt": "MAC",
            "es": "MAC",
            "fr": "MAC",
            "de": "MAC"
        ],
        .recents: [
            "en": "RECENTS",
            "pt": "RECENTES",
            "es": "RECIENTES",
            "fr": "RÉCENTS",
            "de": "ZULETZT VERWENDET"
        ],
        .devices: [
            "en": "DEVICES",
            "pt": "DISPOSITIVOS",
            "es": "DISPOSITIVOS",
            "fr": "DISPOSITIVOS",
            "de": "GERÄTE"
        ],
        .directoryTree: [
            "en": "DIRECTORY TREE",
            "pt": "ÁRVORE DE DIRETÓRIOS",
            "es": "ÁRBOLES DE DIRECTORIOS",
            "fr": "ARBORESCENCE",
            "de": "VERZEICHNISBAUM"
        ],
        .searchPlaceholder: [
            "en": "Search in",
            "pt": "Buscar em",
            "es": "Buscar en",
            "fr": "Rechercher dans",
            "de": "Suchen in"
        ],
        .home: [
            "en": "Home",
            "pt": "Início",
            "es": "Inicio",
            "fr": "Départ",
            "de": "Benutzerordner"
        ],
        .desktop: [
            "en": "Desktop",
            "pt": "Mesa (Desktop)",
            "es": "Escritorio",
            "fr": "Bureau",
            "de": "Schreibtisch"
        ],
        .documents: [
            "en": "Documents",
            "pt": "Documentos",
            "es": "Documentos",
            "fr": "Documents",
            "de": "Dokumente"
        ],
        .downloads: [
            "en": "Downloads",
            "pt": "Downloads",
            "es": "Descargas",
            "fr": "Téléchargements",
            "de": "Downloads"
        ],
        .music: [
            "en": "Music",
            "pt": "Música",
            "es": "Música",
            "fr": "Musique",
            "de": "Musik"
        ],
        .pictures: [
            "en": "Pictures",
            "pt": "Imagens",
            "es": "Imágenes",
            "fr": "Images",
            "de": "Bilder"
        ],
        .movies: [
            "en": "Movies",
            "pt": "Filmes",
            "es": "Películas",
            "fr": "Films",
            "de": "Filme"
        ],
        .trash: [
            "en": "Trash",
            "pt": "Lixeira",
            "es": "Papelera",
            "fr": "Corbeille",
            "de": "Papierkorb"
        ],
        .applications: [
            "en": "Applications",
            "pt": "Aplicativos",
            "es": "Aplicaciones",
            "fr": "Applications",
            "de": "Programme"
        ],
        .airDrop: [
            "en": "AirDrop",
            "pt": "AirDrop",
            "es": "AirDrop",
            "fr": "AirDrop",
            "de": "AirDrop"
        ],
        .iCloudDrive: [
            "en": "iCloud Drive",
            "pt": "iCloud Drive",
            "es": "iCloud Drive",
            "fr": "iCloud Drive",
            "de": "iCloud Drive"
        ],
        .freeSpace: [
            "en": "free",
            "pt": "livre",
            "es": "libre",
            "fr": "libre",
            "de": "frei"
        ],
        .language: [
            "en": "Language",
            "pt": "Idioma",
            "es": "Idioma",
            "fr": "Langue",
            "de": "Sprache"
        ],
        .cancel: [
            "en": "Cancel",
            "pt": "Cancelar",
            "es": "Cancelar",
            "fr": "Annuler",
            "de": "Abbrechen"
        ],
        .create: [
            "en": "Create",
            "pt": "Criar",
            "es": "Crear",
            "fr": "Créer",
            "de": "Erstellen"
        ],
        .createNewFolder: [
            "en": "Create New Folder",
            "pt": "Criar Nova Pasta",
            "es": "Crear Nueva Carpeta",
            "fr": "Créer un nouveau dossier",
            "de": "Neuen Ordner erstellen"
        ],
        .folderNamePlaceholder: [
            "en": "Folder Name",
            "pt": "Nome da Pasta",
            "es": "Nombre de la Carpeta",
            "fr": "Nom du dossier",
            "de": "Ordnername"
        ],
        .defaultFolderName: [
            "en": "New Folder",
            "pt": "Nova Pasta",
            "es": "Nueva Carpeta",
            "fr": "Nouveau dossier",
            "de": "Neuer Ordner"
        ],
        .enterPathPlaceholder: [
            "en": "Enter path...",
            "pt": "Digite o caminho...",
            "es": "Ingrese ruta...",
            "fr": "Entrer le chemin...",
            "de": "Pfad eingeben..."
        ],
        .root: [
            "en": "Root",
            "pt": "Raíz",
            "es": "Raíz",
            "fr": "Racine",
            "de": "Stammverzeichnis"
        ],
        .ascending: [
            "en": "Ascending",
            "pt": "Crescente",
            "es": "Ascendente",
            "fr": "Croissant",
            "de": "Aufsteigend"
        ],
        .location: [
            "en": "Location",
            "pt": "Localização",
            "es": "Ubicación",
            "fr": "Emplacement",
            "de": "Ort"
        ],
        .modified: [
            "en": "Modified",
            "pt": "Modificado",
            "es": "Modificado",
            "fr": "Modifié",
            "de": "Geändert"
        ],
        .hidden: [
            "en": "Hidden",
            "pt": "Oculto",
            "es": "Oculto",
            "fr": "Masqué",
            "de": "Ausgeblendete"
        ],
        .yes: [
            "en": "Yes",
            "pt": "Sim",
            "es": "Sí",
            "fr": "Oui",
            "de": "Ja"
        ],
        .no: [
            "en": "No",
            "pt": "Não",
            "es": "No",
            "fr": "Non",
            "de": "Nein"
        ],
        .close: [
            "en": "Close",
            "pt": "Fechar",
            "es": "Cerrar",
            "fr": "Fermer",
            "de": "Schließen"
        ],
        .parentFolder: [
            "en": "Parent Folder",
            "pt": "Pasta Superior",
            "es": "Carpeta Superior",
            "fr": "Dossier parent",
            "de": "Übergeordneter Ordner"
        ],
        .done: [
            "en": "Done",
            "pt": "Concluído",
            "es": "Hecho",
            "fr": "Terminé",
            "de": "Fertig"
        ],
        .helpShortcuts: [
            "en": "Help & Shortcuts",
            "pt": "Ajuda e Atalhos",
            "es": "Ayuda y Atajos",
            "fr": "Aide et raccourcis",
            "de": "Hilfe & Tastenkürzel"
        ],
        .batchRename: [
            "en": "Batch Rename",
            "pt": "Renomear em Lote",
            "es": "Renombrar en Lote",
            "fr": "Renommer en lot",
            "de": "Stapelumbenennung"
        ],
        .find: [
            "en": "Find",
            "pt": "Localizar",
            "es": "Buscar",
            "fr": "Rechercher",
            "de": "Suchen"
        ],
        .replaceWith: [
            "en": "Replace With",
            "pt": "Substituir Por",
            "es": "Reemplazar por",
            "fr": "Remplacer par",
            "de": "Ersetzen durch"
        ],
        .prefix: [
            "en": "Prefix",
            "pt": "Prefixo",
            "es": "Prefijo",
            "fr": "Préfixe",
            "de": "Präfix"
        ],
        .suffix: [
            "en": "Suffix",
            "pt": "Sufixo",
            "es": "Sufijo",
            "fr": "Suffixe",
            "de": "Suffix"
        ],
        .sequenceNumbering: [
            "en": "Sequence Numbering",
            "pt": "Numeração Sequencial",
            "es": "Numeración Secuencial",
            "fr": "Numérotation séquentielle",
            "de": "Fortlaufende Nummerierung"
        ],
        .startNumber: [
            "en": "Start Number",
            "pt": "Número Inicial",
            "es": "Número Inicial",
            "fr": "Numéro de départ",
            "de": "Startnummer"
        ],
        .preview: [
            "en": "Preview",
            "pt": "Pré-visualização",
            "es": "Previsualización",
            "fr": "Aperçu",
            "de": "Vorschau"
        ],
        .originalName: [
            "en": "Original Name",
            "pt": "Nome Original",
            "es": "Nombre Original",
            "fr": "Nom d'origine",
            "de": "Originalname"
        ],
        .newName: [
            "en": "New Name",
            "pt": "Novo Nome",
            "es": "Nuevo Nombre",
            "fr": "Nouveau nom",
            "de": "Neuer Name"
        ],
        .apply: [
            "en": "Apply",
            "pt": "Aplicar",
            "es": "Aplicar",
            "fr": "Appliquer",
            "de": "Anwenden"
        ],
        .quickConvertImage: [
            "en": "Quick Convert & Resize...",
            "pt": "Conversão Rápida de Imagem...",
            "es": "Conversión Rápida de Imagen...",
            "fr": "Conversion rapide d'image...",
            "de": "Schnelle Bildkonvertierung..."
        ],
        .targetFormat: [
            "en": "Target Format",
            "pt": "Formato de Destino",
            "es": "Formato de Destino",
            "fr": "Format de destination",
            "de": "Zielformat"
        ],
        .resizePreset: [
            "en": "Resize Preset",
            "pt": "Tamanho da Imagem",
            "es": "Tamaño de Imagen",
            "fr": "Taille de l'image",
            "de": "Bildgröße"
        ],
        .cropPreset: [
            "en": "Aspect Ratio Crop",
            "pt": "Recorte de Proporção",
            "es": "Recorte de Aspecto",
            "fr": "Rognage du format",
            "de": "Seitenverhältnis zuschneiden"
        ],
        .quality: [
            "en": "Quality",
            "pt": "Qualidade",
            "es": "Calidad",
            "fr": "Qualité",
            "de": "Qualität"
        ],
        .convert: [
            "en": "Convert",
            "pt": "Converter",
            "es": "Convertir",
            "fr": "Convertir",
            "de": "Konvertieren"
        ],
        .diskUsageVisualizer: [
            "en": "Folder Disk Usage Visualizer",
            "pt": "Visualizador de Uso de Disco",
            "es": "Visualizador de Uso de Disco",
            "fr": "Visualiseur d'espace disque",
            "de": "Speicherplatz-Visualisierung"
        ],
        .topLargestItems: [
            "en": "Top Largest Items",
            "pt": "Principais Itens por Tamanho",
            "es": "Principales Elementos por Tamaño",
            "fr": "Éléments les plus volumineux",
            "de": "Größte Elemente"
        ],
        .aboutWiles: [
            "en": "About Wiles",
            "pt": "Sobre o Wiles",
            "es": "Acerca de Wiles",
            "fr": "À propos de Wiles",
            "de": "Über Wiles"
        ],
        .aboutDescription: [
            "en": "A fast, native macOS file manager designed to bridge the best of GNOME Files (Nautilus) and macOS Finder.",
            "pt": "Um gerenciador de arquivos nativo do macOS, super rápido e projetado para unir o melhor do GNOME Files e Finder.",
            "es": "Un administrador de archivos nativo de macOS, súper rápido y diseñado para unir lo mejor de GNOME Files y Finder.",
            "fr": "Un gestionnaire de fichiers natif de macOS, très rapide et conçu pour réunir le meilleur de GNOME Files et Finder.",
            "de": "Ein nativer macOS-Dateimanager, sehr schnell und entwickelt, um das Beste aus GNOME Files und Finder zu vereinen."
        ],
        .createdBy: [
            "en": "Created by Marco PS",
            "pt": "Criado por Marco PS",
            "es": "Creado por Marco PS",
            "fr": "Créé par Marco PS",
            "de": "Erstellt von Marco PS"
        ],
        .version: [
            "en": "Version",
            "pt": "Versão",
            "es": "Versión",
            "fr": "Version",
            "de": "Version"
        ],
        .translucentLevel: [
            "en": "Translucency Level",
            "pt": "Nível de Transparência",
            "es": "Nivel de Transparencia",
            "fr": "Niveau de Translucidité",
            "de": "Transparenzgrad"
        ],
        .showPreviewSidebar: [
            "en": "Show Preview",
            "pt": "Mostrar Pré-visualização",
            "es": "Mostrar Vista Previa",
            "fr": "Afficher l'aperçu",
            "de": "Vorschau anzeigen"
        ],
        .moreInfo: [
            "en": "More Info...",
            "pt": "Mais Informações...",
            "es": "Más Información...",
            "fr": "Plus d'infos...",
            "de": "Mehr Info..."
        ],
        .general: [
            "en": "General",
            "pt": "Geral",
            "es": "General",
            "fr": "Général",
            "de": "Allgemein"
        ],
        .permissions: [
            "en": "Sharing & Permissions",
            "pt": "Compartilhamento e Permissões",
            "es": "Compartir y Permisos",
            "fr": "Partage et permissions",
            "de": "Freigabe & Zugriffsrechte"
        ],
        .owner: [
            "en": "Owner",
            "pt": "Proprietário",
            "es": "Propietario",
            "fr": "Propriétaire",
            "de": "Eigentümer"
        ],
        .group: [
            "en": "Group",
            "pt": "Grupo",
            "es": "Grupo",
            "fr": "Groupe",
            "de": "Gruppe"
        ],
        .created: [
            "en": "Created",
            "pt": "Criado",
            "es": "Creado",
            "fr": "Créé",
            "de": "Erstellt"
        ],
        .lastOpened: [
            "en": "Last Opened",
            "pt": "Último Acesso",
            "es": "Último Acceso",
            "fr": "Dernière ouverture",
            "de": "Zuletzt geöffnet"
        ],
        .dimensions: [
            "en": "Dimensions",
            "pt": "Dimensões",
            "es": "Dimensiones",
            "fr": "Dimensions",
            "de": "Abmessungen"
        ],
        .duration: [
            "en": "Duration",
            "pt": "Duração",
            "es": "Duración",
            "fr": "Durée",
            "de": "Dauer"
        ],
        .fetchError: [
            "en": "Unable to load properties.",
            "pt": "Não foi possível carregar propriedades.",
            "es": "No se pudieron cargar las propiedades.",
            "fr": "Impossible de charger les propriétés.",
            "de": "Eigenschaften konnten nicht geladen werden."
        ],
        .newFileTitle: [
            "en": "New File",
            "pt": "Novo Arquivo",
            "es": "Nuevo Archivo",
            "fr": "Nouveau Fichier",
            "de": "Neue Datei"
        ],
        .selectTemplate: [
            "en": "Select Template",
            "pt": "Selecionar Template",
            "es": "Seleccionar Plantilla",
            "fr": "Sélectionner un Modèle",
            "de": "Vorlage Auswählen"
        ],
        .fileNameLabel: [
            "en": "File Name",
            "pt": "Nome do Arquivo",
            "es": "Nombre del Archivo",
            "fr": "Nom du Fichier",
            "de": "Dateiname"
        ],
        .extractArchive: [
            "en": "Extract Archive",
            "pt": "Extrair Arquivo",
            "es": "Extraer Archivo",
            "fr": "Extraire L'Archive",
            "de": "Archiv Entpacken"
        ],
        .connectToServer: [
            "en": "Connect to Server",
            "pt": "Conectar ao Servidor",
            "es": "Conectarse al Servidor",
            "fr": "Se Connecter au Serveur",
            "de": "Mit Server Verbinden"
        ],
        .connect: [
            "en": "Connect",
            "pt": "Conectar",
            "es": "Conectar",
            "fr": "Connecter",
            "de": "Verbinden"
        ]
    ]
}
