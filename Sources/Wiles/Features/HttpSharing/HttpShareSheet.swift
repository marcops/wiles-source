import AppKit
import SwiftUI

struct HttpShareSheet: View {
    private static let sheetWidth: CGFloat = 400.0

    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState
    var folderURL: URL

    private var serverService: LocalHttpServerService {
        appState.httpServerService
    }

    @State private var isConfiguring: Bool
    @State private var requireAuth = false
    @State private var password = ""
    /// Lets `onDisappear` skip stopping the server for a minimize dismissal only.
    @State private var isMinimizing = false

    init(appState: AppState, folderURL: URL) {
        self.appState = appState
        self.folderURL = folderURL
        // Reopened from the footer indicator onto an already-running session: skip setup.
        _isConfiguring = State(initialValue: !appState.httpServerService.isRunning && !appState.httpServerService.isStarting)
    }

    private var isSessionActive: Bool {
        serverService.isRunning || serverService.isStarting
    }

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("wifi"),
            title: appState.tr(.shareFolderWifi),
            width: Self.sheetWidth,
            primaryButton: ModalFooterButton(title: appState.tr(isSessionActive ? .wifiShareStopAndClose : .close)) {
                dismiss()
            },
            secondaryButton: isSessionActive
                ? ModalFooterButton(title: appState.tr(.wifiShareMinimize)) {
                    isMinimizing = true
                    dismiss()
                }
                : nil,
            content: { mainContent })
            .onDisappear {
                guard !isMinimizing else { return }
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

                Text(appState.tr(.wifiShareUsernameHint))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(appState.tr(.startSharing)) {
                isConfiguring = false
                serverService.startError = nil
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

            if let urlString = serverService.serverURL {
                shareLinkRow(urlString)
            }

            Text(appState.tr(serverService.isPasswordProtected ? .wifiSharePasswordProtectedNotice : .wifiShareNotice))
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

    @ViewBuilder private var startingServerView: some View {
        if let error = serverService.startError {
            startFailedView(error)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "network.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text(appState.tr(.startingServer))
                    .font(.headline)
            }
        }
    }

    private func startFailedView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(appState.tr(.wifiShareStartFailed))
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(appState.tr(.retry)) {
                serverService.startError = nil
                isConfiguring = true
            }
        }
    }
}
