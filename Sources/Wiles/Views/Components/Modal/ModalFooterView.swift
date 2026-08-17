import SwiftUI

/// The right-aligned secondary/primary button row shared by every modal via `ModalScaffoldView`.
/// Not used standalone outside the scaffold.
struct ModalFooterView: View {
    let primaryButton: ModalFooterButton
    var secondaryButton: ModalFooterButton?

    var body: some View {
        HStack {
            Spacer()
            if let secondaryButton {
                Button(secondaryButton.title, action: secondaryButton.action)
                    .controlSize(.large)
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!secondaryButton.isEnabled)
            }
            Button(primaryButton.title, action: primaryButton.action)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!primaryButton.isEnabled)
        }
        .padding(.horizontal, LayoutTokens.modalFooterHorizontalPadding)
        .padding(.vertical, LayoutTokens.modalFooterVerticalPadding)
    }
}
