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
                switch code {
        case "pt": return pt[key] ?? english[key] ?? key.rawValue
        case "es": return es[key] ?? english[key] ?? key.rawValue
        case "fr": return fr[key] ?? english[key] ?? key.rawValue
        case "de": return de[key] ?? english[key] ?? key.rawValue
        case "zh": return chinese[key] ?? english[key] ?? key.rawValue
        case "ja": return japanese[key] ?? english[key] ?? key.rawValue
        case "ru": return russian[key] ?? english[key] ?? key.rawValue
        case "it": return italian[key] ?? english[key] ?? key.rawValue
        case "ko": return korean[key] ?? english[key] ?? key.rawValue
        case "nl": return dutch[key] ?? english[key] ?? key.rawValue
        case "tr": return turkish[key] ?? english[key] ?? key.rawValue
        case "pl": return polish[key] ?? english[key] ?? key.rawValue
        case "sv": return swedish[key] ?? english[key] ?? key.rawValue
        case "ar": return arabic[key] ?? english[key] ?? key.rawValue
        default: return english[key] ?? key.rawValue
        }
    }

    public enum Key: String, Sendable {
        case newFolder
        case paste
        case selectAll
        case undo
        case redo
        case enclosingFolder
        case wilesHelpAndShortcuts
        case sortBy
        case viewMode
        case gridView
        case listView
        case columnView
        case showHiddenFiles
        case showHiddenFilesGnome
        case showHiddenFilesMac
        case hideStatusBar
        case showStatusBar
        case showFavorites
        case showMacSection
        case showRecents
        case showPlaces
        case showSidebarSectionTitles
        case sidebarMode
        case places
        case directoryTree
        case placesMenuOption
        case treeMenuOption
        case shortcutMode
        case refresh
        case copyPath
        case copyPathAbsolute
        case copyPathRelative
        case copyPathURL
        case copyPathTerminal
        case folderProperties
        case open
        case quickLook
        case removeFromFavorites
        case addToFavorites
        case cut
        case copy
        case copyContent
        case moveToTrash
        case noSelection
        case codePreview
        case sharingActive
        case createSymbolicLink
        case linkType
        case symlinkNameLabel
        case createLink
        case wilesFileManager
        case backgroundOperations
        case noActiveOperations
        case itemsSelectedSuffix
        case activeSuffix
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
        case sidebarTranslucentLevel
        case contentTranslucentLevel
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
        case deleteImmediately
        case secureShred
        case createSymlink
        case compressToTarGz
        case hideTerminal
        case showTerminal
        case hidePreview
        case showNetworkAndCloud
        case back
        case forward
        case goToFolder
        case filterImages
        case filterDocuments
        case filterCodeFiles
        case filterFolders
        case filterPDFs
        case filterLargeFiles
        case filterModified7Days
        case scanningFolderSize
        case backgroundOperations
        case noActiveOperations
        case sharingActive
        case wifiShareNotice
        case startingServer
        case linkType
        case symlinkName
        case noSelection
        case codePreview
        case openWith
        case selectOtherApp
        case downloadFromiCloud
        case smartFolders
        case saveSearch
        case saveAsSmartFolder
        case smartFolderName
        case sharingAndPermissions
        case read
        case write
        case execute
        case applyPermissions
        case compressWithPassword
        case enterPassword
        case password
        case others
        case changeAllDefaultApp
        case recentServers
        case mergeIntoPDF
        case camera
        case lens
        case aperture
        case focalLength
        case dateTaken
        case searchScope
        case searchByName
        case searchByContent
        case inspectArchive
        case permissionDeniedNotice
        case emptyFolder
        case clearSearch
        case grantFullDiskAccess
        case fullDiskAccessNotice
        case findDuplicates
        case duplicateCleanerTitle
        case reclaimableSpace
        case trashSelectedDuplicates
        case noDuplicatesFound
        case batchRenameTitle
        case namingPattern
        case regexReplace
        case emptyTrash
        case emptyTrashConfirm
        case shortcutsNav
        case shortcutsFileActions
        case shortcutsSystem
        case shortcutsOpenFolder
        case shortcutsRename
        case shortcutsToggleHidden
        case shortcutsToggleOverlay
    }
}
