import SwiftUI

/// Direct-in-view rename — replaces the name label in List/Grid/Column with an editable text field
/// instead of popping a modal sheet. Grows downward as the typed name wraps to more lines (matching
/// Finder), and never shifts the icon above/beside it since growth only pushes content that comes
/// after it in the same stack.
struct InlineRenameField: View {
    let item: FileItem
    var appState: AppState
    var windowUIState: WindowUIState
    var font: Font
    var alignment: TextAlignment = .leading

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(alignment)
            .focused($isFocused)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .onAppear {
                text = item.name
                isFocused = true
            }
            .onChange(of: text) { _, newValue in
                // A vertical-axis TextField treats Return as a newline instead of submitting —
                // filenames can never contain one, so any newline that appears (Return, or a
                // pasted multi-line string) is treated as "commit now" and stripped immediately.
                guard newValue.contains("\n") else { return }
                text = newValue.replacingOccurrences(of: "\n", with: "")
                commit()
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onExitCommand { cancel() }
            .accessibilityLabel(appState.tr(.rename))
    }

    private func commit() {
        guard windowUIState.renameItem?.url == item.url else { return }
        windowUIState.renameItem = nil
        appState.performRename(item: item, newName: text)
    }

    private func cancel() {
        guard windowUIState.renameItem?.url == item.url else { return }
        windowUIState.renameItem = nil
    }
}
