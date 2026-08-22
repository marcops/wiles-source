import AppKit
import Foundation

public extension AppState {
    func handleSelection(for item: FileItem, extendSelection: Bool = false) {
        if extendSelection {
            if selection.selectedURLs.contains(item.url) {
                selection.selectedURLs.remove(item.url)
            } else {
                selection.selectedURLs.insert(item.url)
            }
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
            if selection.selectedURLs.contains(item.url) {
                selection.selectedURLs.remove(item.url)
            } else {
                selection.selectedURLs.insert(item.url)
            }
            selection.keyboardSelectionAnchorURL = item.url
        } else if flags.contains(.shift),
                  let anchorURL = selection.keyboardSelectionAnchorURL,
                  let anchorIdx = fileSystem.items.firstIndex(where: { $0.url == anchorURL }),
                  let curIdx = fileSystem.items.firstIndex(where: { $0.url == item.url }) {
            let range = min(anchorIdx, curIdx) ... max(anchorIdx, curIdx)
            let rangeURLs = fileSystem.items[range].map(\.url)
            selection.selectedURLs.formUnion(rangeURLs)
        } else {
            selection.selectedURLs = [item.url]
            selection.keyboardSelectionAnchorURL = item.url
        }
    }
}
