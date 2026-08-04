import SwiftUI
import Observation

public enum SearchScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case name
    case content

    public var id: String { rawValue }
}

@Observable
@MainActor
public final class AppState {
    // MARK: - Domain Stores
    public let navigationStore: NavigationStore
    public let preferencesStore: PreferencesStore
    public let modalStore: ModalStore
    public let selectionStore: SelectionStore
    public let fileSystemStore: FileSystemStore

    // MARK: - Forwarded Navigation Properties
    public var currentURL: URL {
        get { navigationStore.currentURL }
        set { navigationStore.currentURL = newValue }
    }
    public var historyBack: [URL] {
        get { navigationStore.historyBack }
        set { navigationStore.historyBack = newValue }
    }
    public var historyForward: [URL] {
        get { navigationStore.historyForward }
        set { navigationStore.historyForward = newValue }
    }
    public var recentOpenedURLs: [URL] {
        get { navigationStore.recentOpenedURLs }
        set { navigationStore.recentOpenedURLs = newValue }
    }
    public var pathText: String {
        get { navigationStore.pathText }
        set { navigationStore.pathText = newValue }
    }

    // MARK: - Forwarded FileSystem Properties
    public var items: [FileItem] {
        get { fileSystemStore.items }
        set { fileSystemStore.items = newValue }
    }
    public var isLoading: Bool {
        get { fileSystemStore.isLoading }
        set { fileSystemStore.isLoading = newValue }
    }

    func startDirectoryMonitoring(for url: URL) {
        fileSystemStore.startDirectoryMonitoring(for: url) { [weak self] in
            Task { @MainActor in
                self?.refreshCurrentDirectory()
            }
        }
    }

    // MARK: - Forwarded Selection Properties
    public var columnViewDrillRightTrigger: Int {
        get { selectionStore.columnViewDrillRightTrigger }
        set { selectionStore.columnViewDrillRightTrigger = newValue }
    }
    public var columnViewVerticalDirection: Int {
        get { selectionStore.columnViewVerticalDirection }
        set { selectionStore.columnViewVerticalDirection = newValue }
    }
    public var columnViewVerticalTrigger: Int {
        get { selectionStore.columnViewVerticalTrigger }
        set { selectionStore.columnViewVerticalTrigger = newValue }
    }
    public var columnViewMoveLeftTrigger: Int {
        get { selectionStore.columnViewMoveLeftTrigger }
        set { selectionStore.columnViewMoveLeftTrigger = newValue }
    }
    public var gridCellFrames: [URL: CGRect] {
        get { selectionStore.gridCellFrames }
        set { selectionStore.gridCellFrames = newValue }
    }
    public var gridColumnCount: Int {
        selectionStore.gridColumnCount
    }

    // MARK: - Forwarded Preferences Properties
    public var viewMode: ViewMode {
        get { preferencesStore.viewMode }
        set { preferencesStore.viewMode = newValue }
    }
    public var appAppearance: AppAppearance {
        get { preferencesStore.appAppearance }
        set { preferencesStore.appAppearance = newValue }
    }
    public var sidebarMode: SidebarMode {
        get { preferencesStore.sidebarMode }
        set { preferencesStore.sidebarMode = newValue }
    }
    public var sidebarWidth: Double {
        get { preferencesStore.sidebarWidth }
        set { preferencesStore.sidebarWidth = newValue }
    }
    public var sortOption: SortOption {
        get { preferencesStore.sortOption }
        set { preferencesStore.sortOption = newValue }
    }
    public var sortAscending: Bool {
        get { preferencesStore.sortAscending }
        set { preferencesStore.sortAscending = newValue }
    }
    public var showHiddenFiles: Bool {
        get { preferencesStore.showHiddenFiles }
        set { preferencesStore.showHiddenFiles = newValue }
    }
    public var showFavorites: Bool {
        get { preferencesStore.showFavorites }
        set { preferencesStore.showFavorites = newValue }
    }
    public var showRecents: Bool {
        get { preferencesStore.showRecents }
        set { preferencesStore.showRecents = newValue }
    }
    public var showPlaces: Bool {
        get { preferencesStore.showPlaces }
        set { preferencesStore.showPlaces = newValue }
    }
    public var showNetworkAndCloud: Bool {
        get { preferencesStore.showNetworkAndCloud }
        set { preferencesStore.showNetworkAndCloud = newValue }
    }
    public var showSidebarSectionTitles: Bool {
        get { preferencesStore.showSidebarSectionTitles }
        set { preferencesStore.showSidebarSectionTitles = newValue }
    }
    public var appLanguage: AppLanguage {
        get { preferencesStore.appLanguage }
        set { preferencesStore.appLanguage = newValue }
    }
    public var isFavoritesExpanded: Bool {
        get { preferencesStore.isFavoritesExpanded }
        set { preferencesStore.isFavoritesExpanded = newValue }
    }
    public var isMacExpanded: Bool {
        get { preferencesStore.isMacExpanded }
        set { preferencesStore.isMacExpanded = newValue }
    }
    public var isNetworkExpanded: Bool {
        get { preferencesStore.isNetworkExpanded }
        set { preferencesStore.isNetworkExpanded = newValue }
    }
    public var isRecentsExpanded: Bool {
        get { preferencesStore.isRecentsExpanded }
        set { preferencesStore.isRecentsExpanded = newValue }
    }
    public var isDevicesExpanded: Bool {
        get { preferencesStore.isDevicesExpanded }
        set { preferencesStore.isDevicesExpanded = newValue }
    }
    public var isTreeExpanded: Bool {
        get { preferencesStore.isTreeExpanded }
        set { preferencesStore.isTreeExpanded = newValue }
    }
    public var expandedTreePaths: Set<String> {
        get { preferencesStore.expandedTreePaths }
        set { preferencesStore.expandedTreePaths = newValue }
    }
    public var isTagsExpanded: Bool {
        get { preferencesStore.isTagsExpanded }
        set { preferencesStore.isTagsExpanded = newValue }
    }
    public var isSmartFoldersExpanded: Bool {
        get { preferencesStore.isSmartFoldersExpanded }
        set { preferencesStore.isSmartFoldersExpanded = newValue }
    }
    public var searchScope: SearchScope {
        get { preferencesStore.searchScope }
        set { preferencesStore.searchScope = newValue }
    }
    public var showTags: Bool {
        get { preferencesStore.showTags }
        set { preferencesStore.showTags = newValue }
    }
    public var showFooter: Bool {
        get { preferencesStore.showFooter }
        set { preferencesStore.showFooter = newValue }
    }
    public var showTerminalDrawer: Bool {
        get { preferencesStore.showTerminalDrawer }
        set { preferencesStore.showTerminalDrawer = newValue }
    }
    public var showPreviewSidebar: Bool {
        get { preferencesStore.showPreviewSidebar }
        set { preferencesStore.showPreviewSidebar = newValue }
    }
    public var sidebarTranslucentLevel: Int {
        get { preferencesStore.sidebarTranslucentLevel }
        set { preferencesStore.sidebarTranslucentLevel = newValue }
    }
    public var contentTranslucentLevel: Int {
        get { preferencesStore.contentTranslucentLevel }
        set { preferencesStore.contentTranslucentLevel = newValue }
    }
    public var translucentLevel: Int {
        get { preferencesStore.sidebarTranslucentLevel }
        set {
            preferencesStore.sidebarTranslucentLevel = newValue
            preferencesStore.contentTranslucentLevel = newValue
        }
    }
    public var sidebarOverlayOpacity: Double { preferencesStore.sidebarOverlayOpacity }
    public var contentOverlayOpacity: Double { preferencesStore.contentOverlayOpacity }
    public var iconSize: Double {
        get { preferencesStore.iconSize }
        set { preferencesStore.iconSize = newValue }
    }
    public var favoriteURLs: [URL] {
        get { preferencesStore.favoriteURLs }
        set { preferencesStore.favoriteURLs = newValue }
    }

    // MARK: - Forwarded Modal Properties
    public var showSaveSmartFolderSheet: Bool {
        get { modalStore.showSaveSmartFolderSheet }
        set { modalStore.showSaveSmartFolderSheet = newValue }
    }
    public var showPasswordCompressSheet: Bool {
        get { modalStore.showPasswordCompressSheet }
        set { modalStore.showPasswordCompressSheet = newValue }
    }
    public var passwordCompressURLs: [URL]? {
        get { modalStore.passwordCompressURLs }
        set { modalStore.passwordCompressURLs = newValue }
    }
    public var inspectArchiveURL: URL? {
        get { modalStore.inspectArchiveURL }
        set { modalStore.inspectArchiveURL = newValue }
    }
    public var showArchiveInspectionSheet: Bool {
        get { modalStore.showArchiveInspectionSheet }
        set { modalStore.showArchiveInspectionSheet = newValue }
    }
    public var errorMessage: String? {
        get { modalStore.errorMessage }
        set { modalStore.errorMessage = newValue }
    }
    public var showErrorAlert: Bool {
        get { modalStore.showErrorAlert }
        set { modalStore.showErrorAlert = newValue }
    }
    public var showHelpSheet: Bool {
        get { modalStore.showHelpSheet }
        set { modalStore.showHelpSheet = newValue }
    }
    public var showAboutSheet: Bool {
        get { modalStore.showAboutSheet }
        set { modalStore.showAboutSheet = newValue }
    }

    public func showError(_ message: String) {
        modalStore.showError(message)
    }

    // MARK: - Operational State
    public var smartFolders: [SmartFolder] = SmartFolderService.loadSavedSmartFolders()

    public func addSmartFolder(_ folder: SmartFolder) {
        smartFolders.append(folder)
        SmartFolderService.saveSmartFolders(smartFolders)
    }

    public func removeSmartFolder(_ folder: SmartFolder) {
        smartFolders.removeAll { $0.id == folder.id }
        SmartFolderService.saveSmartFolders(smartFolders)
    }

    public static let recentsVirtualURL = URL(fileURLWithPath: "/virtual/recents")

    public var isEditingPath: Bool = false
    public var searchQuery: String = "" {
        didSet {
            refreshCurrentDirectory()
        }
    }
    public var isSearching: Bool = false

    public var selectedURLs: Set<URL> = []
    public var quickLookURL: URL?
    public var clipboard: ClipboardState?
    public var navigationMode: NavigationMode = .gnome {
        didSet { UserDefaults.standard.set(navigationMode.rawValue, forKey: DefaultsKey.navigationMode.rawValue) }
    }

    public var propertiesItem: FileItem?
    public var renameItem: FileItem?
    public var imageConverterItem: FileItem?
    public var symlinkItem: FileItem?
    public var showBatchRenameSheet: Bool = false
    public var showDiskUsageSheet: Bool = false
    public var showNewFolderSheet: Bool = false
    public var showNewFileSheet: Bool = false
    public var trashSizeString: String = ""
    public var showEmptyTrashAlert: Bool = false
    public var showShortcutsHUD: Bool = false
    public var isTrashUpdating: Bool = false
    public var showConnectToServerSheet: Bool = false
    public var showAutoOrganizationSheet: Bool = false
    public var showHttpShareSheet: Bool = false
    public var httpShareFolderURL: URL?

    public var isCompactMode: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.isCompactMode.rawValue) {
        didSet { UserDefaults.standard.set(isCompactMode, forKey: DefaultsKey.isCompactMode.rawValue) }
    }

    public var listColumnStates: [ListColumnState] = ListColumnState.defaults() {
        didSet { saveListColumnStates() }
    }

    public var perFolderViewModes: [String: String] = (UserDefaults.standard.dictionary(forKey: DefaultsKey.perFolderViewModes.rawValue) as? [String: String]) ?? [:] {
        didSet { UserDefaults.standard.set(perFolderViewModes, forKey: DefaultsKey.perFolderViewModes.rawValue) }
    }

    public init() {
        let navStore = NavigationStore()
        let prefStore = PreferencesStore()
        let modStore = ModalStore()
        let selStore = SelectionStore()
        let fsStore = FileSystemStore()

        self.navigationStore = navStore
        self.preferencesStore = prefStore
        self.modalStore = modStore
        self.selectionStore = selStore
        self.fileSystemStore = fsStore

        self.updateTrashSize()
    }

    public func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: appLanguage)
    }

    public var statusText: String {
        let totalCount = items.count
        let selCount = selectedURLs.count

        if selCount == 0 {
            let totalFilesSize = items.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
            if totalFilesSize > 0 {
                let formattedSize = ByteCountFormatter.string(fromByteCount: totalFilesSize, countStyle: .file)
                return "\(totalCount) \(totalCount == 1 ? "item" : "itens") (\(formattedSize))"
            }
            return "\(totalCount) \(totalCount == 1 ? "item" : "itens")"
        } else {
            let selItems = items.filter { selectedURLs.contains($0.url) }
            let selFilesSize = selItems.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
            if selFilesSize > 0 {
                let formattedSize = ByteCountFormatter.string(fromByteCount: selFilesSize, countStyle: .file)
                return "\(selCount) / \(totalCount) (\(formattedSize))"
            } else {
                return "\(selCount) / \(totalCount)"
            }
        }
    }

    public var freeSpaceText: String? {
        if let values = try? currentURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let capacity = values.volumeAvailableCapacity {
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(capacity), countStyle: .file)
            return "\(formatted) \(tr(.freeSpace))"
        }
        return nil
    }

    public func addFavorite(_ url: URL) {
        preferencesStore.favoriteURLs = preferencesStore.favoriteURLs
        let std = url.standardizedFileURL
        if !favoriteURLs.contains(where: { $0.standardizedFileURL == std }) {
            favoriteURLs.append(std)
        }
    }

    public func removeFavorite(_ url: URL) {
        let std = url.standardizedFileURL
        favoriteURLs.removeAll { $0.standardizedFileURL == std }
    }

    public func isFavorite(_ url: URL) -> Bool {
        let std = url.standardizedFileURL
        return favoriteURLs.contains(where: { $0.standardizedFileURL == std })
    }

    public func compressSelectedToZIP() {
        let urls = Array(selectedURLs)
        guard !urls.isEmpty else { return }
        let current = currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileSystemService.compressToZIP(urls: urls, in: current)
            } catch {
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }

    public func extractArchive(url: URL) {
        let current = currentURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileSystemService.extractZIP(archiveURL: url, to: current)
            } catch {
                await MainActor.run { [weak self] in
                    self?.showError(error.localizedDescription)
                }
            }
            await MainActor.run { [weak self] in
                self?.refreshCurrentDirectory()
            }
        }
    }

    public func updateTrashSize() {
        Task { @MainActor in
            self.isTrashUpdating = true
        }
        Task.detached(priority: .background) {
            let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            guard let url = trashURL else {
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
                return
            }
            var totalSize: Int64 = 0
            let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
                return
            }
            while let fileURL = enumerator.nextObject() as? URL {
                if let res = try? fileURL.resourceValues(forKeys: Set(keys)) {
                    if res.isDirectory == false, let size = res.fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
            let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            await MainActor.run { [weak self] in
                self?.trashSizeString = sizeStr
                self?.isTrashUpdating = false
            }
        }
    }

    public func performEmptyTrash() {
        Task { @MainActor in
            self.isTrashUpdating = true
        }
        Task.detached(priority: .userInitiated) {
            let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            guard let url = trashURL else {
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
                return
            }
            let fm = FileManager.default
            guard let paths = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
                await MainActor.run { [weak self] in self?.isTrashUpdating = false }
                return
            }
            for path in paths {
                try? fm.removeItem(at: path)
            }
            await MainActor.run { [weak self] in
                self?.updateTrashSize()
                self?.refreshCurrentDirectory()
            }
        }
    }
}
