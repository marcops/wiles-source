import AppKit
import Foundation

public extension AppState {
    func handleSelection(for item: FileItem, extendSelection: Bool = false) {
        if extendSelection {
            toggleSelectionMembership(of: item.url)
        } else {
            selection.selectedURLs = [item.url]
            selection.keyboardSelectionAnchorURL = item.url
        }
    }

    func handleSelection(for item: FileItem) {
        handleSelection(for: item, modifierFlags: NSEvent.modifierFlags)
    }

    /// Testable seam for `handleSelection(for:)` — real callers go through the overload above,
    /// which reads live `NSEvent.modifierFlags`; tests drive this directly with explicit flags.
    /// Ranges anchor on `selection.keyboardSelectionAnchorURL`, never `selection.selectedURLs.first` — a
    /// `Set` has no stable order, so `.first` would make the shift-click range drift to an
    /// arbitrary already-selected item (see `SelectionStore.keyboardSelectionAnchorURL`'s doc
    /// comment, and the same fix already applied to Shift+Arrow keyboard selection).
    internal func handleSelection(for item: FileItem, modifierFlags flags: NSEvent.ModifierFlags) {
        if flags.contains(.command) {
            toggleSelectionMembership(of: item.url)
        } else if flags.contains(.shift), let rangeURLs = rangeURLs(fromAnchorTo: item) {
            // Redefines the selection from the anchor rather than unioning, so a nearer shift-click
            // can shrink the range back down (matches Finder).
            selection.selectedURLs = Set(rangeURLs)
        } else {
            selection.selectedURLs = [item.url]
            selection.keyboardSelectionAnchorURL = item.url
        }
    }

    /// Toggles `url`'s membership in the selection and moves the shift-click anchor to it.
    private func toggleSelectionMembership(of url: URL) {
        if selection.selectedURLs.contains(url) {
            selection.selectedURLs.remove(url)
        } else {
            selection.selectedURLs.insert(url)
        }
        selection.keyboardSelectionAnchorURL = url
    }

    /// URLs spanned by the current shift-click anchor through `item`, in `fileSystem.items` order.
    private func rangeURLs(fromAnchorTo item: FileItem) -> [URL]? {
        guard let anchorURL = selection.keyboardSelectionAnchorURL,
              let anchorIdx = fileSystem.indexByURL[anchorURL],
              let curIdx = fileSystem.indexByURL[item.url] else { return nil }
        let range = min(anchorIdx, curIdx) ... max(anchorIdx, curIdx)
        return fileSystem.items[range].map(\.url)
    }

    /// The single item a one-target action (open, Quick Look, properties, copy-content) should act
    /// on. `selectedURLs` is a `Set` with no stable order, so `.first` picks an arbitrary member
    /// under multi-selection — use the keyboard anchor while it's still selected, otherwise the
    /// first selected item in visible order.
    var primarySelectedURL: URL? {
        if let anchor = selection.keyboardSelectionAnchorURL, selection.selectedURLs.contains(anchor) {
            return anchor
        }
        return fileSystem.items.first(where: { selection.selectedURLs.contains($0.url) })?.url
            ?? selection.selectedURLs.first
    }

    func toggleSearching() {
        selection.isSearching.toggle()
        if !selection.isSearching {
            selection.searchQuery = ""
        }
    }
}
