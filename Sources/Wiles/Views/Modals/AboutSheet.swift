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
            showsHeader: false,
            width: LayoutTokens.aboutWindowWidth,
            primaryButton: ModalFooterButton(title: appState.tr(.done)) { dismiss() },
            content: { contentArea })
    }

    private var contentArea: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage ?? NSWorkspace.shared.icon(for: .folder))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: LayoutTokens.aboutIconSize, height: LayoutTokens.aboutIconSize)

            VStack(spacing: 4) {
                Text(AppConstants.appName)
                    .font(.system(size: LayoutTokens.aboutTitleFontSize, weight: .bold))
                Text("\(appState.tr(.version)) \(AppConstants.appVersion)")
                    .font(.system(size: LayoutTokens.aboutTextFontSize))
                    .foregroundColor(.secondary)
            }

            Text(appState.tr(.aboutDescription))
                .font(.system(size: LayoutTokens.aboutTextFontSize))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            createdByView
        }
        .padding(.vertical, 32)
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
