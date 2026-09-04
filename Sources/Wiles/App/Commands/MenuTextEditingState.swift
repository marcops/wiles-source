import Foundation

/// Whether a text field owns keyboard focus, so a plain-key menu command (⌘X/C/V/A, Space, Delete)
/// must defer to `NSText` instead of acting on the file selection. Pure so it's window-free testable.
enum MenuTextEditingState {
    static func isActive(
        isTextFieldEditingActive: Bool?,
        isSearching: Bool,
        liveFirstResponderIsText: Bool) -> Bool {
        (isTextFieldEditingActive ?? false) || isSearching || liveFirstResponderIsText
    }
}
