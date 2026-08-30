import SwiftUI

/// Shared "hand-rolled tappable row" pattern (see SWIFT_LANG_RULES.md "Custom Tappable Content MUST Have an Explicit `.contentShape`"): composite
/// content (an icon + text, a padded row) needs its whole visible frame tappable, but a real
/// `Button`/`.onTapGesture` on composite content only responds to its rendered, non-transparent
/// pixels on macOS — clicking the surrounding padding silently does nothing, and a real `Button`
/// doesn't reliably honor `.contentShape` there either. This wraps caller-supplied `content` in
/// `.contentShape(Rectangle())` + `.onTapGesture` plus the accessibility wiring a plain view needs
/// since it's no longer a real control.
///
/// `content` must already include any padding/background/shape styling that should be part of the
/// tappable area — `.contentShape` is applied on top of it, matched to that exact visible frame.
struct TappableRow<Content: View>: View {
    var accessibilityLabel: String?
    var accessibilityHint: String?
    var isSelected: Bool = false
    /// When true, taps are ignored (the caller still owns any dimmed styling). Mirrors a real
    /// control's `.disabled(...)` for this hand-rolled equivalent.
    var isDisabled: Bool = false
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    /// The tap handler, extracted so the enabled/disabled gate is unit-testable without a gesture.
    func handleTap() {
        guard !isDisabled else { return }
        action()
    }

    var body: some View {
        let traits: AccessibilityTraits = isSelected ? [.isButton, .isSelected] : .isButton
        let row = content()
            .contentShape(Rectangle())
            .onTapGesture(perform: handleTap)
            .accessibilityAddTraits(traits)

        if let accessibilityLabel, let accessibilityHint {
            row.accessibilityLabel(accessibilityLabel).accessibilityHint(accessibilityHint)
        } else if let accessibilityLabel {
            row.accessibilityLabel(accessibilityLabel)
        } else if let accessibilityHint {
            row.accessibilityHint(accessibilityHint)
        } else {
            row
        }
    }
}
