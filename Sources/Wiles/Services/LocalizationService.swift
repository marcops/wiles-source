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
        case places
        case directoryTree
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
        case showTags
        case tags
        case red
        case orange
        case yellow
        case green
        case blue
        case purple
        case gray
        case clearAllTags
        case services
        
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
        case compactDensity
        case helpGuideTitle
        case tabOverview
        case tabFeatures
        case tabSystem
        case tabShortcuts
        case overviewDesc
        case domainToolsTitle
        case helpTagsTitle
        case helpTagsDesc
        case helpTerminalTitle
        case helpTerminalDesc
        case helpZipTitle
        case helpZipDesc
        case helpDiskTitle
        case helpDiskDesc
        case helpImageTitle
        case helpImageDesc
        case helpBatchTitle
        case helpBatchDesc
        case helpSymlinkTitle
        case helpSymlinkDesc
        case helpTemplateTitle
        case helpTemplateDesc
        case helpCopyContentTitle
        case helpCopyContentDesc
        case helpShredTitle
        case helpShredDesc
        case helpServerTitle
        case helpServerDesc
        case navSystemTitle
        case helpUndoTitle
        case helpUndoDesc
        case helpPreviewTitle
        case helpPreviewDesc
        case helpViewModeMemoryTitle
        case helpViewModeMemoryDesc
        case helpPathBarTitle
        case helpPathBarDesc
        case helpDragDropTitle
        case helpDragDropDesc
        case helpI18nTitle
        case helpI18nDesc
        case helpTranslucentTitle
        case helpTranslucentDesc
        case navProfilesTitle
        case gnomeModeTitle
        case gnomeModeDesc
        case macModeTitle
        case macModeDesc
        case shortcutsCheatsheetTitle
        case actUndo
        case actRedo
        case actQuickLook
        case actTogglePreview
        case actToggleTerminal
        case actSearch
        case networkAndCloud
        case shareFolderWifi
        case helpWifiShareTitle
        case helpWifiShareDesc
        case helpAutoOrgTitle
        case helpAutoOrgDesc
        case autoOrganization
        case noAutoOrgRules
        case noAutoOrgRulesDesc
        case addNewRule
        case ifFileIn
        case selectFolder
        case ruleValuePlaceholder
        case moveTo
        case addRule
        case actDiskVisualizer
        case actConnectServer
        case actNewFolderShortcut
        case actItemProperties
        case actCopyShortcut
        case actCutShortcut
        case actPasteShortcut
        case actMoveTrash
        case actNavBackForward
        case actParentFolder
        case actRefreshShortcut
        case actToggleStatusBar
        case fullDiskAccessPromptTitle
        case fullDiskAccessPromptMessage
        case openSystemSettings
        case notNow
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
        .places: [
            "en": "Places & Devices",
            "pt": "Locais & Dispositivos",
            "es": "Lugares y Dispositivos",
            "fr": "Emplacements & Dispositifs",
            "de": "Orte & Geräte"
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
        ],
        .showTags: [
            "en": "Show Tags",
            "pt": "Mostrar Etiquetas",
            "es": "Mostrar Etiquetas",
            "fr": "Afficher les étiquettes",
            "de": "Tags anzeigen"
        ],
        .tags: [
            "en": "Tags",
            "pt": "Etiquetas",
            "es": "Etiquetas",
            "fr": "Étiquettes",
            "de": "Tags"
        ],
        .red: ["en": "Red", "pt": "Vermelho", "es": "Rojo", "fr": "Rouge", "de": "Rot"],
        .orange: ["en": "Orange", "pt": "Laranja", "es": "Naranja", "fr": "Orange", "de": "Orange"],
        .yellow: ["en": "Yellow", "pt": "Amarelo", "es": "Amarillo", "fr": "Jaune", "de": "Gelb"],
        .green: ["en": "Green", "pt": "Verde", "es": "Verde", "fr": "Vert", "de": "Grün"],
        .blue: ["en": "Blue", "pt": "Azul", "es": "Azul", "fr": "Bleu", "de": "Blau"],
        .purple: ["en": "Purple", "pt": "Roxo", "es": "Morado", "fr": "Violet", "de": "Lila"],
        .gray: ["en": "Gray", "pt": "Cinza", "es": "Gris", "fr": "Gris", "de": "Grau"],
        .clearAllTags: [
            "en": "Clear All Tags",
            "pt": "Limpar Todas as Etiquetas",
            "es": "Borrar todas las etiquetas",
            "fr": "Effacer toutes les étiquettes",
            "de": "Alle Tags löschen"
        ],
        .services: [
            "en": "Services",
            "pt": "Serviços",
            "es": "Servicios",
            "fr": "Services",
            "de": "Dienste"
        ],
        .compactDensity: [
            "en": "Compact Density Layout",
            "pt": "Layout de Densidade Compacta",
            "es": "Diseño de Densidad Compacta",
            "fr": "Disposition à densité compacte",
            "de": "Kompakte Dichte-Layout"
        ],
        .helpGuideTitle: [
            "en": "Help & Feature Guide",
            "pt": "Guia de Ajuda e Recursos",
            "es": "Guía de Ayuda y Funciones",
            "fr": "Guide d'Aide et Fonctionnalités",
            "de": "Hilfe & Funktionshandbuch"
        ],
        .tabOverview: [
            "en": "Overview",
            "pt": "Visão Geral",
            "es": "Visión General",
            "fr": "Aperçu",
            "de": "Übersicht"
        ],
        .tabFeatures: [
            "en": "Features & Tools",
            "pt": "Recursos e Ferramentas",
            "es": "Funciones y Herramientas",
            "fr": "Fonctionnalités et Outils",
            "de": "Funktionen & Werkzeuge"
        ],
        .tabSystem: [
            "en": "Navigation & System",
            "pt": "Navegação e Sistema",
            "es": "Navegación y Sistema",
            "fr": "Navigation et Système",
            "de": "Navigation & System"
        ],
        .tabShortcuts: [
            "en": "Shortcuts",
            "pt": "Atalhos",
            "es": "Atajos",
            "fr": "Raccourcis",
            "de": "Tastaturkurzbefehle"
        ],
        .overviewDesc: [
            "en": "Wiles is a high-performance, native macOS file manager built with Apple's AppKit and SwiftUI frameworks. It seamlessly bridges GNOME Files (Nautilus) workflow efficiency with macOS Finder's power features.",
            "pt": "O Wiles é um gerenciador de arquivos nativo de alto desempenho para macOS construído com AppKit e SwiftUI. Ele une a eficiência do GNOME Files (Nautilus) aos recursos do macOS Finder.",
            "es": "Wiles es un administrador de archivos nativo de alto rendimiento para macOS construído con AppKit y SwiftUI.",
            "fr": "Wiles est un gestionnaire de fichiers macOS natif et performant.",
            "de": "Wiles ist ein leistungsstarker, nativer macOS-Dateimanager."
        ],
        .domainToolsTitle: [
            "en": "Domain Tools & Feature Highlights",
            "pt": "Ferramentas do Domínio e Destaques",
            "es": "Herramientas del Dominio y Destacados",
            "fr": "Outils du Domaine et Points Forts",
            "de": "Domänenwerkzeuge & Highlights"
        ],
        .helpTagsTitle: [
            "en": "Native macOS Tags & Filtering",
            "pt": "Etiquetas Nativas do macOS e Filtragem",
            "es": "Etiquetas Nativas de macOS y Filtrado",
            "fr": "Étiquettes N 커 de macOS et Filtrage",
            "de": "Native macOS-Tags & Filterung"
        ],
        .helpTagsDesc: [
            "en": "Enable 'Show Tags' in View/Options menu. Right-click any file > Tags to color tag it. Click sidebar color tags or search 'tag:color' to filter.",
            "pt": "Ative 'Mostrar Etiquetas' no menu Visualizar ou Opções. Clique com o botão direito no arquivo > Etiquetas. Clique na barra lateral ou busque 'tag:cor' para filtrar.",
            "es": "Active 'Mostrar Etiquetas' en el menú Vista u Opciones.",
            "fr": "Activez 'Afficher les étiquettes' dans le menu Présentation.",
            "de": "Aktivieren Sie 'Tags anzeigen' im Menü Ansicht."
        ],
        .helpTerminalTitle: [
            "en": "Open in Terminal",
            "pt": "Abrir no Terminal",
            "es": "Abrir en Terminal",
            "fr": "Ouvrir dans le Terminal",
            "de": "Im Terminal öffnen"
        ],
        .helpTerminalDesc: [
            "en": "Right-click any folder or empty background area -> 'Open in Terminal' to launch native Terminal directly at that directory.",
            "pt": "Clique com o botão direito em qualquer pasta ou área vazia -> 'Abrir no Terminal' para abrir o Terminal nativo na pasta atual.",
            "es": "Haga clic derecho en cualquier carpeta -> 'Abrir en Terminal'.",
            "fr": "Faites un clic droit sur n'importe quel dossier -> 'Ouvrir dans le Terminal'.",
            "de": "Rechtsklick auf einen Ordner -> 'Im Terminal öffnen'."
        ],
        .helpZipTitle: [
            "en": "ZIP Archive Compression & Extraction",
            "pt": "Compactação e Extração de Arquivos ZIP",
            "es": "Compresión y Extracción de Archivos ZIP",
            "fr": "Compression et Extraction d'Archives ZIP",
            "de": "ZIP-Archiv-Komprimierung & Extraktion"
        ],
        .helpZipDesc: [
            "en": "Right-click selected files -> 'Compress to ZIP' or right-click any .zip file -> 'Extract Here' for background archive processing.",
            "pt": "Clique com o botão direito nos arquivos -> 'Compactar para ZIP' ou em um .zip -> 'Extrair Aqui'.",
            "es": "Haga clic derecho -> 'Comprimir a ZIP' o 'Extraer Aquí'.",
            "fr": "Clic droit -> 'Compresser en ZIP' ou 'Extraire ici'.",
            "de": "Rechtsklick -> 'In ZIP komprimieren' oder 'Hier entpacken'."
        ],
        .helpDiskTitle: [
            "en": "Disk Space Visualizer",
            "pt": "Visualizador de Espaço em Disco",
            "es": "Visualizador de Espacio en Disco",
            "fr": "Visualiseur d'Espace Disque",
            "de": "Speicherplatz-Visualisierung"
        ],
        .helpDiskDesc: [
            "en": "Press Shift+Cmd+D or choose 'Disk Usage Visualizer...' from background menu to inspect largest files and folder size breakdowns.",
            "pt": "Pressione Shift+Cmd+D ou escolha 'Visualizador de Espaço em Disco...' no menu de contexto para inspecionar os maiores arquivos.",
            "es": "Presione Shift+Cmd+D para inspeccionar archivos grandes.",
            "fr": "Appuyez sur Shift+Cmd+D pour inspecter les fichiers volumineux.",
            "de": "Drücken Sie Umschalt+Cmd+D, um große Dateien zu untersuchen."
        ],
        .helpImageTitle: [
            "en": "Image Quick Converter",
            "pt": "Conversor Rápido de Imagens",
            "es": "Convertidor Rápido de Imágenes",
            "fr": "Convertisseur Rapide d'Images",
            "de": "Schneller Bildkonverter"
        ],
        .helpImageDesc: [
            "en": "Right-click any image -> 'Quick Convert Image...' to batch convert (PNG, JPG, WEBP, HEIC), resize, or crop.",
            "pt": "Clique com o botão direito em uma imagem -> 'Conversão Rápida de Imagem...' para converter formato (PNG, JPG, WEBP, HEIC), redimensionar ou cortar.",
            "es": "Haga clic derecho en una imagen -> 'Conversión Rápida de Imagen...'.",
            "fr": "Clic droit sur une image -> 'Convertir rapidement l'image...'.",
            "de": "Rechtsklick auf ein Bild -> 'Schnelles Konvertieren des Bildes...'."
        ],
        .helpBatchTitle: [
            "en": "Batch Rename Tool",
            "pt": "Ferramenta de Renomeação em Lote",
            "es": "Herramienta de Renombrado en Lote",
            "fr": "Outil de Renommage en Lot",
            "de": "Stapel-Umbenennungswerkzeug"
        ],
        .helpBatchDesc: [
            "en": "Select multiple files and press F2 (or Rename) to open Batch Rename with regex matching, prefix/suffix additions, and sequence numbers.",
            "pt": "Selecione vários arquivos e pressione F2 (ou Renomear) para abrir a renomeação em lote com regex, prefixo, sufixo e numeração.",
            "es": "Seleccione varios archivos y presione F2 para renombrar en lote.",
            "fr": "Sélectionnez plusieurs fichiers et appuyez sur F2.",
            "de": "Wählen Sie mehrere Dateien aus und drücken Sie F2."
        ],
        .helpSymlinkTitle: [
            "en": "Symbolic Link Creation",
            "pt": "Criação de Links Simbólicos (Symlinks)",
            "es": "Creación de Enlaces Simbólicos",
            "fr": "Création de Liens Symboliques",
            "de": "Erstellung Symbolischer Links"
        ],
        .helpSymlinkDesc: [
            "en": "Right-click any file or folder -> 'Create Symlink...' to generate relative or absolute symbolic links.",
            "pt": "Clique com o botão direito -> 'Criar Link Simbólico...' para gerar atalhos de sistema relativos ou absolutos.",
            "es": "Haga clic derecho -> 'Crear Enlace Simbólico...'.",
            "fr": "Clic droit -> 'Créer un lien symbolique...'.",
            "de": "Rechtsklick -> 'Symbolischen Link erstellen...'."
        ],
        .helpTemplateTitle: [
            "en": "New File Templates",
            "pt": "Modelos de Novos Arquivos",
            "es": "Plantillas de Nuevos Archivos",
            "fr": "Modèles de Nouveaux Fichiers",
            "de": "Neue Dateivorlagen"
        ],
        .helpTemplateDesc: [
            "en": "Right-click background -> 'New File...' to quickly generate empty text, markdown, code files, or custom templates.",
            "pt": "Clique com o botão direito na área vazia -> 'Novo Arquivo...' para criar arquivos de texto, código ou modelos rapidamente.",
            "es": "Haga clic derecho en el fondo -> 'Nuevo Archivo...'.",
            "fr": "Clic droit sur l'arrière-plan -> 'Nouveau fichier...'.",
            "de": "Rechtsklick auf den Hintergrund -> 'Neue Datei...'."
        ],
        .helpCopyContentTitle: [
            "en": "Copy File Content to Clipboard",
            "pt": "Copiar Conteúdo do Arquivo para a Área de Transferência",
            "es": "Copiar Contenido del Archivo al Portapapeles",
            "fr": "Copier le Contenu du Fichier dans le Presse-papiers",
            "de": "Dateiinhalt in die Zwischenablage kopieren"
        ],
        .helpCopyContentDesc: [
            "en": "Right-click text/data files -> 'Copy Content' to copy raw file contents directly into your clipboard without opening the file.",
            "pt": "Clique com o botão direito em arquivos de texto -> 'Copiar Conteúdo' para copiar o texto direto para a área de transferência.",
            "es": "Haga clic derecho -> 'Copiar Contenido'.",
            "fr": "Clic droit -> 'Copier le contenu'.",
            "de": "Rechtsklick -> 'Inhalt kopieren'."
        ],
        .helpShredTitle: [
            "en": "Secure File Shredder",
            "pt": "Triturador Seguro de Arquivos",
            "es": "Trituradora Segura de Archivos",
            "fr": "Broyeur Sécurisé de Fichiers",
            "de": "Sicherer Datei-Schredder"
        ],
        .helpShredDesc: [
            "en": "Right-click sensitive files -> 'Secure Shred File...' to permanently overwrite data blocks before unlinking.",
            "pt": "Clique com o botão direito em arquivos sensíveis -> 'Triturar Arquivo...' para sobrescrever blocos de dados antes de excluir permanentemente.",
            "es": "Haga clic derecho -> 'Triturar Archivo...'.",
            "fr": "Clic droit -> 'Broyer le fichier...'.",
            "de": "Rechtsklick -> 'Datei sicher schreddern...'."
        ],
        .helpServerTitle: [
            "en": "Connect to Network Server",
            "pt": "Conectar ao Servidor de Rede",
            "es": "Conectarse al Servidor de Red",
            "fr": "Se Connecter au Serveur Réseau",
            "de": "Mit Netzwerkserver verbinden"
        ],
        .helpWifiShareTitle: [
            "en": "Wi-Fi Folder Sharing",
            "pt": "Compartilhamento Wi-Fi",
            "es": "Compartir por Wi-Fi",
            "fr": "Partage Wi-Fi",
            "de": "WLAN-Freigabe"
        ],
        .helpWifiShareDesc: [
            "en": "Instantly share any folder over your local network via HTTP.",
            "pt": "Compartilhe pastas instantaneamente na sua rede local via HTTP.",
            "es": "Comparte carpetas al instante en tu red local vía HTTP.",
            "fr": "Partagez instantanément n'importe quel dossier sur votre réseau local via HTTP.",
            "de": "Teilen Sie jeden Ordner sofort über Ihr lokales Netzwerk per HTTP."
        ],
        .helpAutoOrgTitle: [
            "en": "Auto-Organization",
            "pt": "Organização Automática",
            "es": "Organización Automática",
            "fr": "Organisation Automatique",
            "de": "Automatische Organisation"
        ],
        .helpAutoOrgDesc: [
            "en": "Set rules to automatically move incoming files into specific folders.",
            "pt": "Crie regras para mover arquivos recebidos automaticamente para pastas.",
            "es": "Crea reglas para mover archivos automáticamente a carpetas específicas.",
            "fr": "Définissez des règles pour déplacer automatiquement les fichiers entrants.",
            "de": "Erstellen Sie Regeln, um eingehende Dateien automatisch in bestimmte Ordner zu verschieben."
        ],
        .helpServerDesc: [
            "en": "Press Cmd+K or choose 'Connect to Server...' in the Options menu to connect to remote SMB, FTP, or SFTP shares.",
            "pt": "Pressione Cmd+K ou escolha 'Conectar ao Servidor...' no menu de opções para conectar a compartilhamentos remotos (SMB, FTP, SFTP).",
            "es": "Presione Cmd+K para conectarse a servidores de red.",
            "fr": "Appuyez sur Cmd+K pour vous connecter à un serveur réseau.",
            "de": "Drücken Sie Cmd+K, um eine Verbindung zu einem Netzwerkserver herzustellen."
        ],
        .navSystemTitle: [
            "en": "Navigation, System & Customization",
            "pt": "Navegação, Sistema e Personalização",
            "es": "Navegación, Sistema y Personalización",
            "fr": "Navigation, Système et Personnalisation",
            "de": "Navigation, System & Anpassung"
        ],
        .helpUndoTitle: [
            "en": "Full Undo / Redo Operations Engine",
            "pt": "Mecanismo Completo de Desfazer / Refazer",
            "es": "Motor Completo de Deshacer / Rehacer",
            "fr": "Moteur Complet Annuler / Rétablir",
            "de": "Vollständige Rückgängig / Wiederholen Engine"
        ],
        .helpUndoDesc: [
            "en": "Press Cmd+Z to undo or Cmd+Shift+Z to redo file renames, creations, moves, and deletions safely.",
            "pt": "Pressione Cmd+Z para desfazer ou Cmd+Shift+Z para refazer renomeações, criações, movimentações e exclusões.",
            "es": "Presione Cmd+Z para deshacer o Cmd+Shift+Z para rehacer.",
            "fr": "Appuyez sur Cmd+Z pour annuler ou Cmd+Shift+Z pour rétablir.",
            "de": "Drücken Sie Cmd+Z zum Rückgängigmachen oder Cmd+Shift+Z zum Wiederholen."
        ],
        .helpPreviewTitle: [
            "en": "Syntax-Highlighted Preview Sidebar",
            "pt": "Barra Lateral de Pré-visualização com Destaque de Sintaxe",
            "es": "Barra Lateral de Vista Previa con Resaltado de Sintaxis",
            "fr": "Barre Latérale d'Aperçu avec Coloration Syntaxique",
            "de": "Vorschau-Seitenleiste mit Syntax-Hervorhebung"
        ],
        .helpPreviewDesc: [
            "en": "Press Shift+Cmd+P or toggle Preview in the View menu to view syntax-highlighted code, markdown, audio, and images without opening apps.",
            "pt": "Pressione Shift+Cmd+P ou ative Pré-visualização para ver códigos com sintaxe destacada, markdown, áudio e imagens.",
            "es": "Presione Shift+Cmd+P para ver vista previa.",
            "fr": "Appuyez sur Shift+Cmd+P pour afficher l'aperçu.",
            "de": "Drücken Sie Umschalt+Cmd+P für die Vorschau-Seitenleiste."
        ],
        .helpViewModeMemoryTitle: [
            "en": "Per-Directory View Mode Memory",
            "pt": "Memória de Modo de Visualização por Diretório",
            "es": "Memoria de Modo de Vista por Directorio",
            "fr": "Mémoire du Mode d'Affichage par Dossier",
            "de": "Ansichtsmodus-Speicher pro Verzeichnis"
        ],
        .helpViewModeMemoryDesc: [
            "en": "Wiles remembers whether you prefer Grid, List, or Column view individually for each folder you navigate.",
            "pt": "O Wiles lembra se você prefere a visualização em Grade, Lista ou Coluna individualmente para cada pasta.",
            "es": "Wiles recuerda la vista preferida para cada carpeta.",
            "fr": "Wiles se souvient du mode d'affichage préféré pour chaque dossier.",
            "de": "Wiles merkt sich den bevorzugten Ansichtsmodus für jeden Ordner."
        ],
        .helpPathBarTitle: [
            "en": "Interactive Path Bar & Breadcrumbs",
            "pt": "Barra de Caminho Interativa (Breadcrumbs)",
            "es": "Barra de Ruta Interactiva",
            "fr": "Barre de Chemin Interactive",
            "de": "Interaktive Pfadleiste"
        ],
        .helpPathBarDesc: [
            "en": "Click any segment in the top or bottom path bar to navigate instantly. Click the edit pencil icon to manually type or paste paths.",
            "pt": "Clique em qualquer segmento da barra de caminho para navegar instantaneamente. Clique no ícone de lápis para digitar caminhos.",
            "es": "Haga clic en cualquier segmento para navegar.",
            "fr": "Cliquez sur n'importe quel segment pour naviguer.",
            "de": "Klicken Sie auf ein Segment, um zu navigieren."
        ],
        .helpDragDropTitle: [
            "en": "Drag & Drop File Operations",
            "pt": "Operações de Arrastar e Soltar (Drag & Drop)",
            "es": "Operaciones de Arrastrar y Soltar",
            "fr": "Glisser-déposer de Fichiers",
            "de": "Drag & Drop Dateivorgänge"
        ],
        .helpDragDropDesc: [
            "en": "Drag files into sidebar favorites, subfolders, or external apps. Supports box marquee selection in Grid and List views.",
            "pt": "Arraste arquivos para os favoritos da barra lateral, subpastas ou aplicativos externos. Suporta seleção por caixa no Grid e Lista.",
            "es": "Arrastre archivos a favoritos o carpetas.",
            "fr": "Glissez des fichiers dans les favoris ou dossiers.",
            "de": "Ziehen Sie Dateien in Favoriten oder Ordner."
        ],
        .helpI18nTitle: [
            "en": "Multi-Language System (i18n)",
            "pt": "Sistema Multi-idioma (i18n)",
            "es": "Sistema Multilingüe (i18n)",
            "fr": "Système Multilingue (i18n)",
            "de": "Mehrsprachiges System (i18n)"
        ],
        .helpI18nDesc: [
            "en": "Automatic macOS system language detection with manual preference overrides (English, Portuguese, Spanish, French, German).",
            "pt": "Detecção automática do idioma do sistema macOS com alteração manual (Inglês, Português, Espanhol, Francês, Alemão).",
            "es": "Detección automática del idioma del sistema con opción manual.",
            "fr": "Détection automatique de la langue avec choix manuel.",
            "de": "Automatische Erkennung der System-Sprache mit manueller Wahl."
        ],
        .helpTranslucentTitle: [
            "en": "Translucent Background & Density Settings",
            "pt": "Fundo Translucido e Configurações de Densidade",
            "es": "Fondo Traslúcido y Configuración de Densidad",
            "fr": "Arrière-plan Translucide et Densité",
            "de": "Transparenter Hintergrund & Dichte-Einstellungen"
        ],
        .helpTranslucentDesc: [
            "en": "Adjust sidebar background glassmorphism (Translucent Level) and enable Compact Density Layout in the Options menu.",
            "pt": "Ajuste a transparência da barra lateral e ative o Layout de Densidade Compacta no menu de Opções.",
            "es": "Ajuste la transparencia y la densidad compacta.",
            "fr": "Ajustez la transparence et la densité compacte.",
            "de": "Passen Sie die Transparenz und die kompakte Dichte an."
        ],
        .navProfilesTitle: [
            "en": "Navigation Shortcut Profiles",
            "pt": "Perfis de Atalho de Navegação",
            "es": "Perfiles de Atajos de Navegación",
            "fr": "Profils de Raccourcis de Navigation",
            "de": "Navigations-Tastaturprofil"
        ],
        .gnomeModeTitle: [
            "en": "GNOME Mode (Default)",
            "pt": "Modo GNOME (Padrão)",
            "es": "Modo GNOME (Predeterminado)",
            "fr": "Mode GNOME (Par défaut)",
            "de": "GNOME-Modus (Standard)"
        ],
        .gnomeModeDesc: [
            "en": "• Enter: Open folder or file\n• F2: Rename item\n• Backspace: Go up to parent folder\n• Ctrl+H: Toggle hidden files",
            "pt": "• Enter: Abrir pasta ou arquivo\n• F2: Renomear item\n• Backspace: Voltar para pasta pai\n• Ctrl+H: Alternar arquivos ocultos",
            "es": "• Enter: Abrir carpeta\n• F2: Renombrar\n• Backspace: Carpeta superior\n• Ctrl+H: Archivos ocultos",
            "fr": "• Entrée: Ouvrir le dossier\n• F2: Renommer\n• Retour arrière: Dossier parent\n• Ctrl+H: Fichiers masqués",
            "de": "• Eingabe: Ordner öffnen\n• F2: Umbenennen\n• Rückschritt: Übergeordneter Ordner\n• Strg+H: Ausgeblendete Dateien"
        ],
        .macModeTitle: [
            "en": "macOS Finder Mode",
            "pt": "Modo macOS Finder",
            "es": "Modo macOS Finder",
            "fr": "Mode macOS Finder",
            "de": "macOS Finder-Modus"
        ],
        .macModeDesc: [
            "en": "• Cmd+Down: Open folder or file\n• Enter: Rename item\n• Cmd+Up: Go up to parent folder\n• Cmd+Shift+.: Toggle hidden files",
            "pt": "• Cmd+Baixo: Abrir pasta ou arquivo\n• Enter: Renomear item\n• Cmd+Cima: Voltar para pasta pai\n• Cmd+Shift+.: Alternar arquivos ocultos",
            "es": "• Cmd+Abajo: Abrir carpeta\n• Enter: Renombrar\n• Cmd+Arriba: Carpeta superior\n• Cmd+Shift+.: Archivos ocultos",
            "fr": "• Cmd+Bas: Ouvrir le dossier\n• Entrée: Renommer\n• Cmd+Haut: Dossier parent\n• Cmd+Shift+.: Fichiers masqués",
            "de": "• Cmd+Runter: Ordner öffnen\n• Eingabe: Umbenennen\n• Cmd+Hoch: Übergeordneter Ordner\n• Cmd+Shift+.: Ausgeblendete Dateien"
        ],
        .shortcutsCheatsheetTitle: [
            "en": "Keyboard Shortcuts Cheatsheet",
            "pt": "Lista de Atalhos de Teclado",
            "es": "Lista de Atajos de Teclado",
            "fr": "Aide-mémoire des Raccourcis Clavier",
            "de": "Tastaturkurzbefehle Übersicht"
        ],
        .actUndo: ["en": "Undo Operation", "pt": "Desfazer Operação", "es": "Deshacer Operación", "fr": "Annuler l'opération", "de": "Vorgang rückgängig machen"],
        .actRedo: ["en": "Redo Operation", "pt": "Refazer Operação", "es": "Rehacer Operación", "fr": "Rétablir l'opération", "de": "Vorgang wiederholen"],
        .actQuickLook: ["en": "Quick Look Preview", "pt": "Pré-visualização Quick Look", "es": "Vista Previa Quick Look", "fr": "Aperçu Coup d'œil", "de": "Übersicht-Vorschau"],
        .actTogglePreview: ["en": "Toggle Preview Sidebar", "pt": "Alternar Barra de Pré-visualização", "es": "Alternar Barra Lateral de Vista Previa", "fr": "Basculer la barre d'aperçu", "de": "Vorschau-Seitenleiste umschalten"],
        .actToggleTerminal: ["en": "Toggle Terminal Drawer", "pt": "Alternar Terminal Integrado", "es": "Alternar Terminal Integrado", "fr": "Basculer le terminal intégré", "de": "Integriertes Terminal umschalten"],
        .actSearch: ["en": "Search in Directory", "pt": "Pesquisar no Diretório", "es": "Buscar en el Directorio", "fr": "Rechercher dans le dossier", "de": "Im Verzeichnis suchen"],
        .networkAndCloud: ["en": "NETWORK & CLOUD", "pt": "REDE E NUVEM", "es": "RED Y NUBE", "fr": "RÉSEAU ET CLOUD", "de": "NETZWERK & CLOUD"],
        .shareFolderWifi: ["en": "Share Folder over Wi-Fi", "pt": "Compartilhar Pasta por Wi-Fi", "es": "Compartir Carpeta por Wi-Fi", "fr": "Partager le dossier via Wi-Fi", "de": "Ordner über WLAN freigeben"],
        .autoOrganization: ["en": "Auto-Organization Rules...", "pt": "Regras de Organização Automática...", "es": "Reglas de Organización Automática...", "fr": "Règles d'organisation automatique...", "de": "Regeln für automatische Organisation..."],
        .noAutoOrgRules: ["en": "No Auto-Organization Rules", "pt": "Nenhuma Regra", "es": "Sin reglas", "fr": "Aucune règle", "de": "Keine Regeln"],
        .noAutoOrgRulesDesc: ["en": "Files will stay where they are.", "pt": "Os arquivos não serão movidos.", "es": "Los archivos no se moverán.", "fr": "Les fichiers ne seront pas déplacés.", "de": "Dateien bleiben, wo sie sind."],
        .addNewRule: ["en": "Add New Rule", "pt": "Adicionar Nova Regra", "es": "Añadir nueva regla", "fr": "Ajouter une nouvelle règle", "de": "Neue Regel hinzufügen"],
        .ifFileIn: ["en": "If file in:", "pt": "Se arquivo em:", "es": "Si el archivo en:", "fr": "Si fichier dans:", "de": "Wenn Datei in:"],
        .selectFolder: ["en": "Select Folder...", "pt": "Selecionar Pasta...", "es": "Seleccionar carpeta...", "fr": "Sélectionner un dossier...", "de": "Ordner auswählen..."],
        .ruleValuePlaceholder: ["en": "Value (e.g. pdf)", "pt": "Valor (ex: pdf)", "es": "Valor (ej: pdf)", "fr": "Valeur (ex: pdf)", "de": "Wert (z.B. pdf)"],
        .moveTo: ["en": "Move to:", "pt": "Mover para:", "es": "Mover a:", "fr": "Déplacer vers:", "de": "Verschieben nach:"],
        .addRule: ["en": "Add Rule", "pt": "Adicionar Regra", "es": "Añadir regla", "fr": "Ajouter la règle", "de": "Regel hinzufügen"],
        .actDiskVisualizer: ["en": "Disk Usage Visualizer", "pt": "Visualizador de Uso de Disco", "es": "Visualizador de Uso de Disco", "fr": "Visualiseur d'espace disque", "de": "Speicherplatz-Visualisierung"],
        .actConnectServer: ["en": "Connect to Server", "pt": "Conectar ao Servidor", "es": "Conectarse al Servidor", "fr": "Se connecter au serveur", "de": "Mit Server verbinden"],
        .actNewFolderShortcut: ["en": "New Folder", "pt": "Nova Pasta", "es": "Nueva Carpeta", "fr": "Nouveau dossier", "de": "Neuer Ordner"],
        .actItemProperties: ["en": "Item Properties / Info", "pt": "Propriedades / Informações do Item", "es": "Propiedades / Información del Elemento", "fr": "Propriétés du fichier", "de": "Element-Eigenschaften / Info"],
        .actCopyShortcut: ["en": "Copy Selected", "pt": "Copiar Selecionado", "es": "Copiar Seleccionado", "fr": "Copier la sélection", "de": "Auswahl kopieren"],
        .actCutShortcut: ["en": "Cut Selected", "pt": "Recortar Selecionado", "es": "Cortar Seleccionado", "fr": "Couper la sélection", "de": "Auswahl ausschneiden"],
        .actPasteShortcut: ["en": "Paste Files", "pt": "Colar Arquivos", "es": "Pegar Archivos", "fr": "Coller les fichiers", "de": "Dateien einfügen"],
        .actMoveTrash: ["en": "Move to Trash", "pt": "Mover para o Lixo", "es": "Mover a la Papelera", "fr": "Placer dans la corbeille", "de": "In den Papierkorb verschieben"],
        .actNavBackForward: ["en": "Navigate Back / Forward", "pt": "Navegar Voltar / Avançar", "es": "Navegar Atrás / Adelante", "fr": "Naviguer Précédent / Suivant", "de": "Zurück / Vorwärts navigieren"],
        .actParentFolder: ["en": "Parent Folder", "pt": "Pasta Pai (Superior)", "es": "Carpeta Superior", "fr": "Dossier parent", "de": "Übergeordneter Ordner"],
        .actRefreshShortcut: ["en": "Refresh Directory", "pt": "Atualizar Diretório", "es": "Actualizar Directorio", "fr": "Actualiser le dossier", "de": "Verzeichnis aktualisieren"],
        .actToggleStatusBar: ["en": "Toggle Status Bar", "pt": "Alternar Barra de Status", "es": "Alternar Barra de Estado", "fr": "Basculer la barre d'état", "de": "Statusleiste umschalten"],
        .fullDiskAccessPromptTitle: ["en": "Full Disk Access", "pt": "Acesso Total ao Disco", "es": "Acceso Total al Disco", "fr": "Accès complet au disque", "de": "Voller Festplattenzugriff"],
        .fullDiskAccessPromptMessage: [
            "en": "Wiles needs Full Disk Access to browse all your folders without repeated permission prompts. Grant it once in System Settings.",
            "pt": "O Wiles precisa de Acesso Total ao Disco para navegar em todas as suas pastas sem pedir permissão repetidamente. Conceda uma vez nos Ajustes do Sistema.",
            "es": "Wiles necesita Acceso Total al Disco para explorar todas tus carpetas sin solicitudes de permiso repetidas. Concédelo una vez en Ajustes del Sistema.",
            "fr": "Wiles a besoin d'un accès complet au disque pour parcourir tous vos dossiers sans demandes d'autorisation répétées. Accordez-le une fois dans Réglages Système.",
            "de": "Wiles benötigt vollen Festplattenzugriff, um alle Ordner ohne wiederholte Berechtigungsanfragen zu durchsuchen. Erteile ihn einmal in den Systemeinstellungen."
        ],
        .openSystemSettings: ["en": "Open System Settings", "pt": "Abrir Ajustes do Sistema", "es": "Abrir Ajustes del Sistema", "fr": "Ouvrir Réglages Système", "de": "Systemeinstellungen öffnen"],
        .notNow: ["en": "Not Now", "pt": "Agora Não", "es": "Ahora No", "fr": "Plus tard", "de": "Nicht jetzt"]
    ]
}
