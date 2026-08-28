import SwiftUI

/// The failure state for `AsyncResultView` — a warning glyph over a short message. Kept separate
/// from each feature's empty state so "couldn't complete" never reads as "nothing found".
struct AsyncErrorStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
