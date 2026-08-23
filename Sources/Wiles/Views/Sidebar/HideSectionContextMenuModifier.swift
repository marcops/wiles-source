import SwiftUI

/// `@ViewBuilder` can't conditionally attach `.contextMenu` itself (it's a modifier, not a
/// view-producing branch), so this isolates the "attach only when hideAction exists" logic.
struct HideSectionContextMenuModifier: ViewModifier {
    let title: String
    let hideAction: (() -> Void)?
    var appState: AppState

    func body(content: Content) -> some View {
        if let hideAction {
            content.contextMenu {
                Button(String(format: appState.tr(.hideSectionMenuItem), title), action: hideAction)
            }
        } else {
            content
        }
    }
}
