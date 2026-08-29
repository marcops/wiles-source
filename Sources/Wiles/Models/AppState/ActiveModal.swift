import Foundation

/// The single modal sheet this window is currently presenting, or `nil` for none. Replaces the
/// former mix of `showXSheet: Bool` flags and `xItem: FileItem?` / `xURL: URL?` presence signals
/// on `WindowUIState`: one `.sheet(item:)` in `WilesModalSheets` switches on this, so "sheet shown
/// but no payload" states are no longer representable. Confirmation `.alert`s and the manual
/// `ShortcutsHUDOverlay` are not sheets and keep their own flags on `WindowUIState`.
public enum ActiveModal: Identifiable, Hashable {
    case properties(FileItem)
    case imageConverter(FileItem)
    case symlink(FileItem)
    case httpShare(URL)
    case inspectArchive(URL)
    case passwordCompress([URL])
    case batchRename
    case connectToServer
    case autoOrganization
    case duplicateCleaner
    case saveSmartFolder
    case help
    case feedback
    case about
    case settings

    public var id: Self {
        self
    }
}
