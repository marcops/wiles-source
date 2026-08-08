import SwiftUI
import AppKit

struct AboutSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.openURL)
    private var openURL

    var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
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
                .padding(.top, 8)
            }
            .padding(.vertical, 32)

            Divider()
            footerView
        }
        .frame(width: LayoutTokens.aboutWindowWidth)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var footerView: some View {
        HStack {
            Spacer()
            Button(appState.tr(.done)) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .accessibilityLabel(appState.tr(.done))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
