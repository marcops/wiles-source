import AppKit
import SwiftUI

public struct ConnectToServerSheetView: View {
    private static let maxRecentServers = 10
    private static let contentWidth: CGFloat = 320.0

    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    @State private var serverAddress: String = ""
    @State private var recentServers: [String] = []

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ModalScaffoldView(
            icon: .symbol("network"),
            title: appState.tr(.connectToServer),
            subtitle: appState.tr(.connectToServerSubtitle),
            width: 360,
            primaryButton: ModalFooterButton(
                title: appState.tr(.connect),
                isEnabled: !serverAddress.trimmingCharacters(in: .whitespaces).isEmpty) {
                    performConnect()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { formContent })
            .task { recentServers = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentConnectServers.rawValue) ?? [] }
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
        TextField(appState.tr(.serverAddressPlaceholder), text: $serverAddress)
            .textFieldStyle(.roundedBorder)
            .frame(width: Self.contentWidth)
            .accessibilityLabel(appState.tr(.connectToServer))
    }

    private var recentServersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.recentServers))
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recentServers, id: \.self) { server in
                        recentServerRow(server)
                    }
                }
            }
            .frame(maxHeight: 100)
        }
        .frame(width: Self.contentWidth)
    }

    private func recentServerRow(_ server: String) -> some View {
        RecentServerRow(server: server, onSelect: { serverAddress = server }, onRemove: { removeRecentServer(server) }, appState: appState)
    }

    private func removeRecentServer(_ server: String) {
        recentServers.removeAll { $0 == server }
        UserDefaults.standard.set(recentServers, forKey: DefaultsKey.recentConnectServers.rawValue)
    }

    private func performConnect() {
        let address = serverAddress.trimmingCharacters(in: .whitespaces)
        guard !address.isEmpty else { return }

        do {
            try NetworkServerService.connectToServer(urlAddress: address)
            var history = recentServers
            history.removeAll { $0 == address }
            history.insert(address, at: 0)
            if history.count > Self.maxRecentServers {
                history = Array(history.prefix(Self.maxRecentServers))
            }
            UserDefaults.standard.set(history, forKey: DefaultsKey.recentConnectServers.rawValue)
            dismiss()
        } catch {
            appState.showError(error, context: "Connecting to server \(address)")
        }
    }
}
