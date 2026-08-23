import AppKit
import SwiftUI

struct AboutSheet: View {
    private static let windowWidth: CGFloat = 400.0
    private static let iconSize: CGFloat = 80.0
    private static let titleFontSize: CGFloat = 24.0
    private static let textFontSize: CGFloat = 13.0

    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.openURL)
    private var openURL

    var appState: AppState
    @State private var didPushLinkCursor = false

    var body: some View {
        ModalScaffoldView(
            icon: .appIcon,
            title: AppConstants.appName,
            showsHeader: false,
            width: Self.windowWidth,
            primaryButton: ModalFooterButton(title: appState.tr(.done)) { dismiss() },
            content: { contentArea })
    }

    private var contentArea: some View {
        VStack(spacing: 16) {
            Image(nsImage: ModalIcon.resolvedAppIcon)
                .resizable()
                .scaledToFit()
                .frame(width: Self.iconSize, height: Self.iconSize)

            VStack(spacing: 4) {
                Text(AppConstants.appName)
                    .font(.system(size: Self.titleFontSize, weight: .bold))
                Text("\(appState.tr(.version)) \(AppConstants.appVersion)")
                    .font(.system(size: Self.textFontSize))
                    .foregroundColor(.secondary)
            }

            Text(appState.tr(.aboutDescription))
                .font(.system(size: Self.textFontSize))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            createdByView
        }
        .padding(.vertical, 32)
    }

    private var createdByView: some View {
        VStack(spacing: 6) {
            Text(appState.tr(.createdBy))
                .font(.system(size: Self.textFontSize, weight: .medium))
            githubLinkRow
        }
    }

    private var githubLinkRow: some View {
        TappableRow(
            accessibilityLabel: AppConstants.githubDisplayString,
            action: {
                if let url = URL(string: AppConstants.githubURL) {
                    openURL(url)
                }
            },
            content: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                    Text(AppConstants.githubDisplayString)
                }
                .foregroundColor(.accentColor)
            })
            .onHover { isHovered in
                if isHovered, !didPushLinkCursor {
                    NSCursor.pointingHand.push()
                    didPushLinkCursor = true
                } else if !isHovered, didPushLinkCursor {
                    NSCursor.pop()
                    didPushLinkCursor = false
                }
            }
            .onDisappear {
                if didPushLinkCursor {
                    NSCursor.pop()
                    didPushLinkCursor = false
                }
            }
    }
}
