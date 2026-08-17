import AppKit
import SwiftUI

struct AboutSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.openURL)
    private var openURL

    var appState: AppState

    var body: some View {
        ModalScaffoldView(
            icon: .appIcon,
            title: AppConstants.appName,
            subtitle: "\(appState.tr(.version)) \(AppConstants.appVersion)",
            width: LayoutTokens.aboutWindowWidth,
            primaryButton: ModalFooterButton(title: appState.tr(.done)) { dismiss() },
            content: { contentArea })
    }

    private var contentArea: some View {
        VStack(spacing: 16) {
            Text(appState.tr(.aboutDescription))
                .font(.system(size: LayoutTokens.aboutTextFontSize))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            createdByView
        }
        .padding(.vertical, 24)
    }

    private var createdByView: some View {
        VStack(spacing: 6) {
            Text(appState.tr(.createdBy))
                .font(.system(size: LayoutTokens.aboutTextFontSize, weight: .medium))

            HStack(spacing: 6) {
                Image(systemName: "link")
                Text(AppConstants.githubDisplayString)
            }
            .foregroundColor(.accentColor)
            .contentShape(Rectangle())
            .onTapGesture {
                if let url = URL(string: AppConstants.githubURL) {
                    openURL(url)
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(AppConstants.githubDisplayString)
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}
