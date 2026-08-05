import SwiftUI

struct SingleInputSheetView: View {
    let title: String
    let iconName: String?
    let initialValue: String
    let actionButtonTitle: String
    let cancelTitle: String
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    init(
        title: String,
        iconName: String? = nil,
        initialValue: String = "",
        actionButtonTitle: String = "OK",
        cancelTitle: String = "Cancel",
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (String) -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.initialValue = initialValue
        self.actionButtonTitle = actionButtonTitle
        self.cancelTitle = cancelTitle
        self.onCancel = onCancel
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }

            TextField("", text: $textValue)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .accessibilityLabel(title)
                .onSubmit { submit() }

            HStack(spacing: 12) {
                Spacer()
                Button(cancelTitle) {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel(cancelTitle)

                Button(actionButtonTitle) {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(actionButtonTitle)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(textValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            textValue = initialValue
            isFocused = true
        }
    }

    private func submit() {
        let trimmed = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }
}
