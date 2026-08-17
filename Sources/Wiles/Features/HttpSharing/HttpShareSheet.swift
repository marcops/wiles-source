import AppKit
import SwiftUI

struct HttpShareSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState
    var folderURL: URL

    @State private var serverService = LocalHttpServerService.shared
    @State private var isConfiguring = true
    @State private var requireAuth = false
    @State private var password = ""

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("wifi"),
            title: appState.tr(.shareFolderWifi),
            width: LayoutTokens.httpShareSheetWidth,
            height: LayoutTokens.httpShareSheetHeight,
            primaryButton: ModalFooterButton(title: appState.tr(.close)) {
                serverService.stop()
                dismiss()
            },
            content: { mainContent })
            .onDisappear {
                serverService.stop()
            }
    }

    private var mainContent: some View {
        VStack(spacing: 20) {
            if isConfiguring {
                setupSection
            } else {
                statusSection
            }
            Spacer()
        }
        .padding(20)
    }

    private var setupSection: some View {
        VStack(spacing: 16) {
            Toggle(appState.tr(.requirePassword), isOn: $requireAuth)

            if requireAuth {
                SecureField(appState.tr(.enterPassword), text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            Button(appState.tr(.startSharing)) {
                isConfiguring = false
                serverService.start(sharing: folderURL, password: requireAuth ? password : nil)
            }
            .buttonStyle(.borderedProminent)
            .disabled(requireAuth && password.isEmpty)
        }
    }

    @ViewBuilder private var statusSection: some View {
        if serverService.isRunning {
            activeSharingView
        } else {
            startingServerView
        }
    }

    private var activeSharingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text(appState.tr(.sharingActive))
                .font(.headline)
                .foregroundColor(.green)

            Text(folderURL.lastPathComponent)
                .font(.subheadline)
                .fontWeight(.semibold)

            if let urlString = serverService.serverURL {
                shareLinkRow(urlString)
            }

            Text(appState.tr(requireAuth ? .wifiSharePasswordProtectedNotice : .wifiShareNotice))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func shareLinkRow(_ urlString: String) -> some View {
        HStack {
            Text(urlString)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(urlString, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help(appState.tr(.copyContent))
            .accessibilityLabel(appState.tr(.copyLinkAccessibilityLabel))
            .accessibilityHint(appState.tr(.copyLinkAccessibilityHint))
        }
    }

    private var startingServerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(appState.tr(.startingServer))
                .font(.headline)
        }
    }
}
