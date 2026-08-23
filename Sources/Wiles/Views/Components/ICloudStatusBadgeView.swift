import SwiftUI

public struct ICloudStatusBadgeView: View {
    private static let badgeProgressScale: Double = 0.5
    private static let badgeSize: CGFloat = 14.0
    private static let downloadIconFontSize: CGFloat = 11.0
    private static let uploadIconFontSize: CGFloat = 10.0

    let item: FileItem
    var appState: AppState

    public init(item: FileItem, appState: AppState) {
        self.item = item
        self.appState = appState
    }

    public var body: some View {
        if item.isUbiquitousDownloading {
            ProgressView()
                .scaleEffect(Self.badgeProgressScale)
                .frame(width: Self.badgeSize, height: Self.badgeSize)
                .accessibilityLabel(appState.tr(.iCloudStatusDownloading))
        } else if item.isUbiquitousNotDownloaded {
            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: Self.downloadIconFontSize, weight: .bold))
                .foregroundColor(.accentColor)
                .accessibilityLabel(appState.tr(.iCloudStatusNotDownloaded))
        } else if item.isUbiquitousUploading {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: Self.uploadIconFontSize, weight: .semibold))
                .foregroundColor(.secondary)
                .accessibilityLabel(appState.tr(.iCloudStatusUploading))
        }
    }
}
