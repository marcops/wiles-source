import SwiftUI
import AppKit

struct FooterBarView: View {
    var appState: AppState
    @State private var isIconSizeControlExpanded = false

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

            if !BackgroundOperationsService.shared.activeTasks.isEmpty {
                OperationsButtonView()
            }

            iconSizeControl(appState: appState)

            Divider().frame(height: 12)

            // Terminal toggle button
            Button(action: {
                withAnimation { appState.showTerminalDrawer.toggle() }
            }) {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(appState.showTerminalDrawer ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Terminal (Cmd+J)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(height: 26)
    }

    /// Collapses down to just an icon; hovering near it reveals the slider to adjust icon size.
    private func iconSizeControl(appState: AppState) -> some View {
        @Bindable var appState = appState
        return HStack(alignment: .center, spacing: 6) {
            Image(systemName: "photo")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)

            if isIconSizeControlExpanded {
                Slider(value: $appState.iconSize, in: 36...128, step: 2)
                    .frame(width: 100)
                    .controlSize(.mini)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                Image(systemName: "photo")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, isIconSizeControlExpanded ? 6 : 4)
        .frame(height: 20)
        .background(Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isIconSizeControlExpanded = hovering }
        }
        .help("Ajustar tamanho dos ícones (Cmd/Ctrl + Wheel ou Cmd/Ctrl + +/-)")
    }
}

struct OperationsButtonView: View {
    @State private var showPopover = false
    
    var body: some View {
        Button(action: { showPopover.toggle() }) {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("\(BackgroundOperationsService.shared.activeTasks.count) background tasks")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            OperationsPopoverView()
        }
    }
}
