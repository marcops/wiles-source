import SwiftUI

/// The icon/title/subtitle row (plus an optional accessory like a tab switcher) shared by every
/// modal via `ModalScaffoldView`. Not used standalone outside the scaffold.
struct ModalHeaderView<Accessory: View>: View {
    let icon: ModalIcon
    let title: String
    var subtitle: String?
    var iconSize: CGFloat = LayoutTokens.modalHeaderIconSize
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                icon.view(size: iconSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: LayoutTokens.modalTitleFontSize, weight: .bold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: LayoutTokens.modalSubtitleFontSize))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            accessory()
        }
        .padding(.horizontal, LayoutTokens.modalHeaderHorizontalPadding)
        .padding(.vertical, LayoutTokens.modalHeaderVerticalPadding)
    }
}
