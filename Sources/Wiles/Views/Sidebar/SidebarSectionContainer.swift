import SwiftUI

/// Shared section scaffold used by every collapsible sidebar section — owns the
/// show-title/show-content visibility rule so it can't drift between sections.
struct SidebarSectionContainer<Content: View>: View {
    var appState: AppState
    let title: String
    let identifierKey: String
    @Binding var isExpanded: Bool
    /// Set by `SidebarView.collapsibleSection` for the compact rail, where the header hides but
    /// its items still render as an icon-only list.
    var hideHeader: Bool = false
    var forceShowContent: Bool = false
    var hideAction: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !hideHeader, appState.preferences.showSidebarSectionTitles {
                SidebarSectionHeaderView(title: title, identifierKey: identifierKey, appState: appState, isExpanded: $isExpanded, hideAction: hideAction)
            }
            if shouldShowContent {
                content()
            }
        }
    }

    private var shouldShowContent: Bool {
        forceShowContent || !appState.preferences.showSidebarSectionTitles || isExpanded
    }
}
