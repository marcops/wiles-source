import SwiftUI

/// Config for one `ModalScaffoldView` footer button. The scaffold owns sizing/placement/keyboard
/// shortcut; callers only supply the title, enabled state, and action.
struct ModalFooterButton {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void
}
