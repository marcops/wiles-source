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
                    appState.compressSelectedToZIPWithPassword(password, urls: windowUIState.passwordCompressURLs)
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
