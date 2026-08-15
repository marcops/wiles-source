import Foundation
import AppKit

extension AppState {
    public func handleSelection(for item: FileItem, extendSelection: Bool = false) {
        if extendSelection {
            if selectedURLs.contains(item.url) {
                selectedURLs.remove(item.url)
            } else {
                selectedURLs.insert(item.url)
            }
        } else {
            selectedURLs = [item.url]
            selection.keyboardSelectionAnchorURL = item.url
        }
    }

    public func handleSelection(for item: FileItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selectedURLs.contains(item.url) {
                selectedURLs.remove(item.url)
            } else {
                selectedURLs.insert(item.url)
            }
        } else if flags.contains(.shift),
            let last = selectedURLs.first,
            let lastIdx = fileSystem.items.firstIndex(where: { $0.url == last }),
            let curIdx = fileSystem.items.firstIndex(where: { $0.url == item.url }) {
            let range = min(lastIdx, curIdx)...max(lastIdx, curIdx)
            let rangeURLs = fileSystem.items[range].map { $0.url }
            selectedURLs.formUnion(rangeURLs)
        } else {
            selectedURLs = [item.url]
        }
    }
}
