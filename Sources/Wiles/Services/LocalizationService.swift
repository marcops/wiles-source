import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case english = "en"
    case portuguese = "pt"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case dutch = "nl"
    case polish = "pl"
    case russian = "ru"
    case swedish = "sv"
    case turkish = "tr"
    case chinese = "zh-Hans"
    case arabic = "ar"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .portuguese: return "Português"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        case .russian: return "Русский"
        case .swedish: return "Svenska"
        case .turkish: return "Türkçe"
        case .chinese: return "中文"
        case .arabic: return "العربية"
        }
    }
}

public struct L10n {
    public static func activeCode(_ preferred: AppLanguage) -> String {
        if preferred != .system { return preferred.rawValue }
        let supportedCodes = AppLanguage.allCases.map { $0.rawValue }
        for preference in Locale.preferredLanguages {
            let lower = preference.lowercased()
            if let match = supportedCodes.first(where: { lower.hasPrefix($0.lowercased()) }) {
                return match
            }
        }
        return "en"
    }

    private static let resourceBundle: Bundle = .module

    public static func string(_ key: Key, lang: AppLanguage) -> String {
        let code = activeCode(lang)
        if let path = resourceBundle.path(forResource: code, ofType: "lproj") ?? resourceBundle.path(forResource: code.lowercased(), ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
        }
        return resourceBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
    }

    public enum Key: String, Sendable, CaseIterable {
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
        case createSymbolicLink
        case symlinkNameLabel
        case createLink
        case wilesFileManager
        case itemsSelectedSuffix
        case activeSuffix
        case backgroundTasksSuffix
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
        case sidebarTrash
        case sidebarDocuments
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
        case goMenuTitle
        case toolsMenuTitle
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
