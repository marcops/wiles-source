import SwiftUI
import AppKit

struct PasswordCompressSheetView: View {
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(appState.tr(.compressWithPassword))
                .font(.headline)

            SecureField(appState.tr(.enterPassword), text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            HStack {
                Button(appState.tr(.cancel)) {
                    dismiss()
                }
                Spacer()
                Button("OK") {
                    if let urls = appState.modal.passwordCompressURLs {
                        do {
                            try ArchiveService.compressToZIP(urls: urls, in: appState.navigation.currentURL, password: password)
                            appState.refreshCurrentDirectory()
                        } catch {
                            appState.showError(error.localizedDescription)
                        }
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
