import SwiftUI
import AppKit

struct FooterBarView: View {
    var appState: AppState
    
    var body: some View {
        @Bindable var appState = appState
        
        HStack(spacing: 12) {
            // Status text (item counts, total/selection sizes, free disk space)
            HStack(spacing: 4) {
                Text(appState.statusText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                
                if let freeSpace = appState.freeSpaceText {
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(freeSpace)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            .lineLimit(1)
            
            Spacer()
            
            // Icon Size Zoom Slider (Grid/List View icon scaling)
            HStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                
                Slider(value: $appState.iconSize, in: 36...128, step: 2)
                    .frame(width: 110)
                    .controlSize(.mini)
                
                Image(systemName: "photo")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .help("Ajustar tamanho dos ícones (Cmd/Ctrl + Wheel ou Cmd/Ctrl + +/-)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(height: 26)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
