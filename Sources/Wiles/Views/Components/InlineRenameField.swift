import SwiftUI

/// Direct-in-view rename — replaces the name label in List/Grid with an editable text field
/// instead of popping a modal sheet. Grows downward as the typed name wraps to more lines (matching
/// Finder), and never shifts the icon above/beside it since growth only pushes content that comes
/// after it in the same stack.
struct InlineRenameField: View {
    let item: FileItem
    var appState: AppState
    var windowUIState: WindowUIState
    var font: Font
    var alignment: TextAlignment = .leading
    var horizontalPadding: CGFloat = 4
    /// Grid only: measured against `text` to compute an explicit height, since `TextField`'s own
    /// `axis: .vertical` sizing reserves one line more than the text actually wraps to.
    var lineHeightMeasurement: (nsFont: NSFont, availableWidth: CGFloat)?

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var explicitHeight: CGFloat? {
        guard let measurement = lineHeightMeasurement else { return nil }
        return Self.computeHeight(text: text, nsFont: measurement.nsFont, availableWidth: measurement.availableWidth)
    }

    /// Pure line-count-to-height math, extracted so a unit test can drive it directly.
    static func computeHeight(text: String, nsFont: NSFont, availableWidth: CGFloat) -> CGFloat {
        let lineCount = max(1, FinderStyleTruncationService.wrappedLines(text, font: nsFont, maxWidth: availableWidth).count)
        let singleLineHeight = nsFont.ascender - nsFont.descender + nsFont.leading
        return singleLineHeight * CGFloat(lineCount) + LayoutTokens.gridCardLabelVerticalPadding
    }

    var body: some View {
        TextField("", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(alignment)
            .focused($isFocused)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 2)
            .frame(height: explicitHeight)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.textBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 1.5))
            .onAppear {
                text = item.name
                // Deferred a tick: right after a context-menu action (e.g. New Folder), the
                // menu is still returning key focus to the window — requesting focus in the
                // same run-loop turn loses that race and the field appears but isn't typable.
                Task { @MainActor in
                    isFocused = true
                }
            }
            .onKeyPress(phases: .down) { keyPress in
                // A vertical-axis TextField treats Return as a newline instead of submitting, and
                // relying on that newline showing up in the bound `text` (then stripping it) was
                // unreliable — intercepting the key press directly here commits deterministically
                // and prevents the newline from ever reaching the binding. Checked without a fixed
                // `.onKeyPress(.return)` filter because the numeric-keypad Enter key reports as the
                // legacy ETX character (`\u{3}`), not `.return` (`\r`) — filtering to only `.return`
                // silently drops that key.
                guard isCommitKeyPress(keyPress) else { return .ignored }
                commit()
                return .handled
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    commit()
                }
            }
            .onExitCommand { cancel() }
            .accessibilityLabel(appState.tr(.rename))
            .accessibilityIdentifier("InlineRenameField")
    }

    private func commit() {
        guard windowUIState.renameItem?.url == item.url else { return }
        windowUIState.renameItem = nil
        endSuppressedRefreshIfNeeded()
        appState.performRename(item: item, newName: text)
    }

    private func cancel() {
        guard windowUIState.renameItem?.url == item.url else { return }
        // Refresh before nulling `renameItem`: that fires `onRenameCleared`, which resets
        // `renamingURL` and would make `endSuppressedRefreshIfNeeded`'s guard fail.
        endSuppressedRefreshIfNeeded()
        windowUIState.renameItem = nil
    }

    private func endSuppressedRefreshIfNeeded() {
        guard appState.fileSystem.renamingURL == item.url else { return }
        appState.fileSystem.renamingURL = nil
        appState.refreshCurrentDirectory()
    }

    private func isCommitKeyPress(_ keyPress: KeyPress) -> Bool {
        Self.isCommitCharacter(keyPress.key.character)
    }

    /// The main Return key reports `"\r"`; the numeric-keypad Enter key reports the legacy ETX
    /// character `"\u{3}"` instead — both must commit the rename. Extracted as a plain, testable
    /// function since `KeyPress` itself has no public initializer a unit test could construct.
    static func isCommitCharacter(_ character: Character) -> Bool {
        character == "\r" || character == "\u{3}"
    }
}
