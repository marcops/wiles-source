import SwiftUI

/// Asks the user how to resolve a move name-collision (Replace / Keep Both / Cancel), optionally
/// remembering the choice for the rest of the batch. Always resolves `prompt` exactly once —
/// including on an unexpected dismiss — so the awaiting move loop can't hang.
struct MoveCollisionSheet: View {
    private static let sheetWidth: CGFloat = 420

    var appState: AppState
    let prompt: MoveCollisionPrompt

    @State private var applyToAll = false

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("doc.on.doc"),
            title: title,
            subtitle: appState.tr(.moveCollisionMessage),
            width: Self.sheetWidth,
            primaryButton: ModalFooterButton(title: appState.tr(.moveCollisionKeepBoth)) { finish(.keepBoth) },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { finish(.cancel) },
            content: { content })
            .onDisappear { finish(.cancel) }
    }

    private var title: String {
        appState.tr(.moveCollisionTitle).replacingOccurrences(of: "{name}", with: prompt.itemName)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(role: .destructive) { finish(.replace) } label: {
                Text(appState.tr(.moveCollisionReplace)).frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .accessibilityLabel(appState.tr(.moveCollisionReplace))

            if prompt.showApplyToAll {
                Toggle(appState.tr(.moveCollisionApplyToAll), isOn: $applyToAll)
                    .accessibilityLabel(appState.tr(.moveCollisionApplyToAll))
            }
        }
        .padding(20)
    }

    /// `prompt.resolve` is idempotent, so the `.onDisappear` call is a no-op once a button answered.
    private func finish(_ action: MoveCollisionChoice.Action) {
        prompt.resolve(MoveCollisionChoice(action: action, applyToAll: applyToAll))
    }
}
