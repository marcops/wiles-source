import AppKit
import SwiftUI

struct PasswordCompressSheetView: View {
    var appState: AppState
    let urls: [URL]
    @Environment(\.dismiss)
    private var dismiss
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    private var passwordsMatch: Bool {
        password == confirmPassword
    }

    private var passwordHasForbiddenCharacters: Bool {
        ArchiveService.passwordHasForbiddenCharacters(password)
    }

    private var canSubmit: Bool {
        !password.isEmpty && passwordsMatch && !passwordHasForbiddenCharacters && !urls.isEmpty
    }

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("lock.fill"),
            title: appState.tr(.compressWithPassword),
            subtitle: appState.tr(.passwordCompressSubtitle),
            width: 300,
            primaryButton: ModalFooterButton(
                title: appState.tr(.confirm),
                isEnabled: canSubmit) {
                    appState.compressSelectedToZIPWithPassword(password, urls: urls)
                    dismiss()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { passwordFields })
    }

    private var passwordFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField(appState.tr(.enterPassword), text: $password)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(appState.tr(.enterPassword))
                .accessibilityHint(appState.tr(.archivePasswordFieldHint))
            SecureField(appState.tr(.confirmPassword), text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(appState.tr(.confirmPassword))
            if !confirmPassword.isEmpty, !passwordsMatch {
                Text(appState.tr(.passwordMismatchHint))
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            if passwordHasForbiddenCharacters {
                Text(appState.tr(.archivePasswordInvalidCharacters))
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
        .padding(20)
    }
}
