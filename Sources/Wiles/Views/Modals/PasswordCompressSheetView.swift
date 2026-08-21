import AppKit
import SwiftUI

struct PasswordCompressSheetView: View {
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @Environment(\.dismiss)
    private var dismiss
    @State private var password: String = ""

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("lock.fill"),
            title: appState.tr(.compressWithPassword),
            width: 300,
            primaryButton: ModalFooterButton(
                title: appState.tr(.confirm),
                isEnabled: !password.isEmpty) {
                    appState.compressSelectedToZIPWithPassword(password, urls: windowUIState.passwordCompressURLs)
                    dismiss()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { passwordField })
    }

    private var passwordField: some View {
        SecureField(appState.tr(.enterPassword), text: $password)
            .textFieldStyle(.roundedBorder)
            .padding(20)
            .accessibilityLabel(appState.tr(.enterPassword))
            .accessibilityHint(appState.tr(.archivePasswordFieldHint))
    }
}
