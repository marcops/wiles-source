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
}
