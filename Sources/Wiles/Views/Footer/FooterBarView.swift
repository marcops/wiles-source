import SwiftUI
import AppKit

struct FooterBarView: View {
    var appState: AppState
    @State private var isIconSizeControlExpanded = false
    // Free-space lookup is a synchronous disk call (`resourceValues(forKeys:)`) that can block for
    // seconds on a stalled SMB mount. It's loaded asynchronously via `.task` below and read passively
    // here instead of computed synchronously in `body`, which `@Observable` re-runs on nearly every
    // state change the footer observes.
    @State private var freeSpaceText: String?

    var body: some View {
        @Bindable var appState = appState

        HStack(spacing: 12) {
            // Status text (item counts, total/selection sizes, free disk space)
            HStack(spacing: 4) {
                Text(appState.statusText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("Status Bar")

                if let freeSpace = freeSpaceText {
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

            if appState.fileSystem.isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(appState.tr(.refresh))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(4)
            }

            if !BackgroundOperationsService.shared.activeTasks.isEmpty {
                OperationsButtonView(appState: appState)
            }

            iconSizeControl(appState: appState)

            Divider().frame(height: 12)

            // Terminal toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { appState.preferences.showTerminalDrawer.toggle() }
            } label: {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(appState.preferences.showTerminalDrawer ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appState.tr(.actToggleTerminal))
            .accessibilityHint(appState.tr(.actToggleTerminal))
            .help(appState.tr(.actToggleTerminal))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(height: 26)
        .task(id: appState.navigation.currentURL) {
            freeSpaceText = await appState.loadFreeSpaceText()
        }
    }

    /// Collapses down to just an icon; hovering near it reveals the slider to adjust icon size.
    private func iconSizeControl(appState: AppState) -> some View {
        @Bindable var appState = appState
        return HStack(alignment: .center, spacing: 6) {
            Image(systemName: "photo")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)

            if isIconSizeControlExpanded {
                Slider(value: $appState.preferences.iconSize, in: 36...128, step: 2)
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
            withAnimation(MotionTokens.quickEase) { isIconSizeControlExpanded = hovering }
        }
        .help("Ajustar tamanho dos ícones (Cmd/Ctrl + Wheel ou Cmd/Ctrl + +/-)")
    }
}

struct OperationsButtonView: View {
    var appState: AppState
    @State private var showPopover = false

    var body: some View {
        Button { showPopover.toggle() } label: {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("\(BackgroundOperationsService.shared.activeTasks.count) \(appState.tr(.backgroundTasksSuffix))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("OperationsProgressButton")
        .popover(isPresented: $showPopover) {
            OperationsPopoverView(appState: appState)
        }
    }
}
