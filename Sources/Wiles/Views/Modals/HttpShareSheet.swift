import SwiftUI
import AppKit

struct HttpShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    var appState: AppState
    var folderURL: URL
    
    @State private var serverService = LocalHttpServerService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "wifi")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                Text(appState.tr(.shareFolderWifi))
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 10)
            
            if serverService.isRunning {
                VStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Sharing Active")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text(folderURL.lastPathComponent)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if let urlString = serverService.serverURL {
                        HStack {
                            Text(urlString)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(urlString, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                            }
                            .help(appState.tr(.copyContent))
                        }
                    }
                    
                    Text("Anyone on your Wi-Fi network can access this folder by visiting the address above.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("Starting Server...")
                        .font(.headline)
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button(appState.tr(.close)) {
                    serverService.stop()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400, height: 320)
        .onAppear {
            serverService.start(sharing: folderURL)
        }
        .onDisappear {
            serverService.stop()
        }
    }
}
