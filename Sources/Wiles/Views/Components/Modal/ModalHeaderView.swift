import SwiftUI

/// The icon/title/subtitle row (plus an optional accessory like a tab switcher) shared by every
/// modal via `ModalScaffoldView`. Not used standalone outside the scaffold.
struct ModalHeaderView<Accessory: View>: View {
    /// `static let` isn't allowed on a generic type, so these are computed instead.
    private static var titleFontSize: CGFloat {
        16.0
    }

    private static var subtitleFontSize: CGFloat {
        12.0
    }

    private static var horizontalPadding: CGFloat {
        20.0
    }

    private static var verticalPadding: CGFloat {
        14.0
    }

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
                        .font(.system(size: Self.titleFontSize, weight: .bold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: Self.subtitleFontSize))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            accessory()
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
    }
}
