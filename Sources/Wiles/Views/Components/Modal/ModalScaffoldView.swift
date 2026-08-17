import SwiftUI

/// Standard header/content/footer skeleton every modal in this app must be built on (see
/// WILES_UI_UX_RULES.md's "Standard Modal Scaffold" rule). Header, content, and footer share one
/// background so the sheet reads as a single surface — only icon/title/subtitle, an optional
/// header accessory (a tab switcher, etc.), the content body, and the footer buttons vary between
/// modals; layout, spacing, typography, and button sizing come from here so every modal matches.
struct ModalScaffoldView<HeaderAccessory: View, Content: View>: View {
    let icon: ModalIcon
    let title: String
    var subtitle: String?
    let width: CGFloat
    var height: CGFloat?
    let primaryButton: ModalFooterButton
    var secondaryButton: ModalFooterButton?
    @ViewBuilder var headerAccessory: () -> HeaderAccessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content()
            Divider()
            footer
        }
        .frame(width: width, height: height)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                icon.view(size: LayoutTokens.modalHeaderIconSize)

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

            headerAccessory()
        }
        .padding(.horizontal, LayoutTokens.modalHeaderHorizontalPadding)
        .padding(.vertical, LayoutTokens.modalHeaderVerticalPadding)
    }

    private var footer: some View {
        HStack {
            Spacer()
            if let secondaryButton {
                Button(secondaryButton.title, action: secondaryButton.action)
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!secondaryButton.isEnabled)
            }
            Button(primaryButton.title, action: primaryButton.action)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(!primaryButton.isEnabled)
        }
        .padding(.horizontal, LayoutTokens.modalFooterHorizontalPadding)
        .padding(.vertical, LayoutTokens.modalFooterVerticalPadding)
    }
}

extension ModalScaffoldView where HeaderAccessory == EmptyView {
    init(
        icon: ModalIcon,
        title: String,
        subtitle: String? = nil,
        width: CGFloat,
        height: CGFloat? = nil,
        primaryButton: ModalFooterButton,
        secondaryButton: ModalFooterButton? = nil,
        @ViewBuilder content: @escaping () -> Content) {
        self.init(
            icon: icon,
            title: title,
            subtitle: subtitle,
            width: width,
            height: height,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton,
            headerAccessory: { EmptyView() },
            content: content)
    }
}
