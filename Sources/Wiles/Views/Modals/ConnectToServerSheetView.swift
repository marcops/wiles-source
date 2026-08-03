import SwiftUI
import AppKit

public struct ConnectToServerSheetView: View {
    var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var serverAddress: String = "smb://"
    @State private var recentServers: [String] = (UserDefaults.standard.stringArray(forKey: "wiles_recentConnectServers")) ?? []
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.title)
                    .foregroundColor(.accentColor)
                Text(appState.tr(.connectToServer))
                    .font(.headline)
            }
            
            TextField("smb://server/share", text: $serverAddress)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
            
            if !recentServers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.tr(.recentServers))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(recentServers, id: \.self) { server in
                                Button(action: { serverAddress = server }) {
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
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
                .frame(width: 320)
            }
            
            HStack {
                Button(appState.tr(.cancel)) {
                    dismiss()
                }
                Spacer()
                Button(appState.tr(.connect)) {
                    performConnect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(serverAddress.isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }
    
    private func performConnect() {
        let address = serverAddress.trimmingCharacters(in: .whitespaces)
        guard !address.isEmpty else { return }
        
        var history = recentServers
        history.removeAll { $0 == address }
        history.insert(address, at: 0)
        if history.count > 10 { history = Array(history.prefix(10)) }
        UserDefaults.standard.set(history, forKey: "wiles_recentConnectServers")
        
        do {
            try NetworkServerService.connectToServer(urlAddress: address)
            dismiss()
        } catch {
            appState.showError(error.localizedDescription)
        }
    }
}
