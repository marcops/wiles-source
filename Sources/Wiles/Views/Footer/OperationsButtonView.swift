import SwiftUI

struct OperationsButtonView: View {
    var appState: AppState
    @State private var showPopover = false

    var body: some View {
        Button { showPopover.toggle() } label: {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("\(appState.backgroundOperations.activeTasks.count) \(appState.tr(.backgroundTasksSuffix))")
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
        .accessibilityLabel(appState.tr(.backgroundOperations))
        .accessibilityHint(appState.tr(.operationsButtonHint))
        .popover(isPresented: $showPopover) {
            OperationsPopoverView(appState: appState)
        }
    }
}
