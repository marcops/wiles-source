import SwiftUI

public struct ICloudStatusBadgeView: View {
    let item: FileItem
    var appState: AppState

    public init(item: FileItem, appState: AppState) {
        self.item = item
        self.appState = appState
    }

    public var body: some View {
        if item.isUbiquitousDownloading {
            ProgressView()
                .scaleEffect(LayoutTokens.iCloudStatusBadgeProgressScale)
                .frame(width: LayoutTokens.iCloudStatusBadgeSize, height: LayoutTokens.iCloudStatusBadgeSize)
                .accessibilityLabel(appState.tr(.iCloudStatusDownloading))
        } else if item.isUbiquitousNotDownloaded {
            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: LayoutTokens.iCloudStatusDownloadIconFontSize, weight: .bold))
                .foregroundColor(.accentColor)
                .accessibilityLabel(appState.tr(.iCloudStatusNotDownloaded))
        } else if item.isUbiquitousUploading {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: LayoutTokens.iCloudStatusUploadIconFontSize, weight: .semibold))
                .foregroundColor(.secondary)
                .accessibilityLabel(appState.tr(.iCloudStatusUploading))
        }
    }
}
