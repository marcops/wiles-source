import SwiftUI

/// `identifierKey` is a fixed, non-localized key (e.g. "FAVORITES") kept separate from the
/// localized `title` shown on screen — accessibility identifiers must stay stable across
/// languages so UI tests and automation don't break when the OS language changes.
/// See SWIFT_LANG_RULES.md "Custom Tappable Content MUST Have an Explicit `.contentShape`": a real `Button` on macOS does not reliably honor `.contentShape`
/// for
/// composite (icon + text) label content, so this uses a plain view + `.onTapGesture` instead.
struct SidebarSectionHeaderView: View {
    let title: String
    let identifierKey: String
    var appState: AppState
    @Binding var isExpanded: Bool
    /// Sections with a corresponding `preferences.showX` toggle pass this in so the header offers
    /// a one-item "Hide <Section>" context menu — the same toggle Settings already exposes.
    var hideAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 12)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(MotionTokens.quickEase) {
                isExpanded.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Section_\(identifierKey)")
        .accessibilityLabel(title)
        .accessibilityHint(appState.tr(.expandCollapseFolderHint))
        .accessibilityValue(appState.tr(isExpanded ? .collapseFolder : .expandFolder))
        .modifier(HideSectionContextMenuModifier(title: title, hideAction: hideAction, appState: appState))
    }
}
