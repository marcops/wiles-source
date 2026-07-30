import SwiftUI
import AppKit

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            
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
                    
                    Button(action: {
                        if let url = URL(string: AppConstants.githubURL) {
                            openURL(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                            Text(AppConstants.githubDisplayString)
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
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
    
    private var headerView: some View {
        HStack {
            Text(appState.tr(.aboutWiles))
                .font(.system(size: 14, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private var footerView: some View {
        HStack {
            Spacer()
            Button(appState.tr(.done)) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
