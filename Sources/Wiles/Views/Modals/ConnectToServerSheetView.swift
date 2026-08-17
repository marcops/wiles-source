import AppKit
import SwiftUI

public struct ConnectToServerSheetView: View {
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    @State private var serverAddress: String = "smb://"
    @State private var recentServers: [String] = (UserDefaults.standard.stringArray(forKey: DefaultsKey.recentConnectServers.rawValue)) ?? []

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ModalScaffoldView(
            icon: .symbol("network"),
            title: appState.tr(.connectToServer),
            width: 360,
            primaryButton: ModalFooterButton(
                title: appState.tr(.connect),
                isEnabled: !serverAddress.isEmpty) {
                    performConnect()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { formContent })
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            addressField
            if !recentServers.isEmpty {
                recentServersSection
            }
        }
        .padding(20)
    }

    private var addressField: some View {
        TextField("smb://server/share", text: $serverAddress)
            .textFieldStyle(.roundedBorder)
            .frame(width: 320)
    }

    private var recentServersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.recentServers))
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recentServers, id: \.self) { server in
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.secondary)
                            Text(server)
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                        .onTapGesture { serverAddress = server }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(Text(server))
                    }
                }
            }
            .frame(maxHeight: 100)
        }
        .frame(width: 320)
    }

    private func performConnect() {
        let address = serverAddress.trimmingCharacters(in: .whitespaces)
        guard !address.isEmpty else { return }

        var history = recentServers
        history.removeAll { $0 == address }
        history.insert(address, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        UserDefaults.standard.set(history, forKey: DefaultsKey.recentConnectServers.rawValue)

        do {
            try NetworkServerService.connectToServer(urlAddress: address)
            dismiss()
        } catch {
            appState.showError(error.localizedDescription)
        }
    }
}
