import SwiftUI

/// Standard header/content/footer skeleton every modal in this app must be built on (see
/// WILES_UI_UX_RULES.md's "Standard Modal Scaffold" rule). Header, content, and footer share one
/// background so the sheet reads as a single surface — only icon/title/subtitle, an optional
/// header accessory (a tab switcher, etc.), the content body, and the footer buttons vary between
/// modals; layout, spacing, typography, and button sizing come from `ModalHeaderView`/`ModalFooterView`.
struct ModalScaffoldView<HeaderAccessory: View, Content: View>: View {
    let icon: ModalIcon
    let title: String
    var subtitle: String?
    var iconSize: CGFloat = LayoutTokens.modalHeaderIconSize
    /// Toggles the icon/title/subtitle row (and its divider) on or off — off for the rare modal
    /// whose identity reads better as centered content than a left-aligned banner (see `AboutSheet`).
    var showsHeader: Bool = true
    let width: CGFloat
    var height: CGFloat?
    let primaryButton: ModalFooterButton
    var secondaryButton: ModalFooterButton?
    @ViewBuilder var headerAccessory: () -> HeaderAccessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                ModalHeaderView(icon: icon, title: title, subtitle: subtitle, iconSize: iconSize, accessory: headerAccessory)
                Divider()
            }
            content()
            Divider()
            ModalFooterView(primaryButton: primaryButton, secondaryButton: secondaryButton)
        }
        .frame(width: width, height: height)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

extension ModalScaffoldView where HeaderAccessory == EmptyView {
    init(
        icon: ModalIcon,
        title: String,
        subtitle: String? = nil,
        iconSize: CGFloat = LayoutTokens.modalHeaderIconSize,
        showsHeader: Bool = true,
        width: CGFloat,
        height: CGFloat? = nil,
        primaryButton: ModalFooterButton,
        secondaryButton: ModalFooterButton? = nil,
        @ViewBuilder content: @escaping () -> Content) {
        self.init(
            icon: icon,
            title: title,
            subtitle: subtitle,
            iconSize: iconSize,
            showsHeader: showsHeader,
            width: width,
            height: height,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton,
            headerAccessory: { EmptyView() },
            content: content)
    }
}
