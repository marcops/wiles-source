import SwiftUI

/// Fallback content shown inside `QLPreviewInlineView` when the native `QLPreviewView` fails to
/// initialize (e.g. under memory pressure) instead of crashing the app.
struct QLPreviewUnavailableView: View {
    var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))

            Text(appState.tr(.previewUnavailable))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
