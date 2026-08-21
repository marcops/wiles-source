import AppKit
import SwiftUI

struct PreviewSidebarView: View {
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var detailedProps: DetailedFileProperties?

    var body: some View {
        VStack {
            if appState.selectedURLs.isEmpty {
                Text(appState.tr(.noSelection)).foregroundColor(.secondary)
            } else if appState.selectedURLs.count == 1 {
                singleSelectionView
            } else {
                Text("\(appState.selectedURLs.count) \(appState.tr(.itemsSelectedSuffix))").foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 350, maxHeight: .infinity)
        .padding()
        .translucentBackground(material: .sidebar, opacity: appState.preferences.sidebarOverlayOpacity)
        .task(id: appState.selectedURLs) {
            if let first = appState.selectedURLs.first, appState.selectedURLs.count == 1 {
                detailedProps = await FileMetadataService.shared.fetchProperties(for: first)
            } else {
                detailedProps = nil
            }
        }
    }

    @ViewBuilder private var singleSelectionView: some View {
        if let first = appState.selectedURLs.first, let item = appState.fileSystem.items.first(where: { $0.url == first }) {
            VStack(alignment: .center, spacing: 16) {
                FileItemIconView(item: item, size: 120)
                    .id(item.url)

                Text(item.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Divider()

                propertyRows(for: item)

                nativePreview(for: item)

                Spacer()

                Button(appState.tr(.moreInfo)) {
                    windowUIState.propertiesItem = item
                }
                .buttonStyle(.link)
                .accessibilityLabel(appState.tr(.moreInfo))
                .accessibilityHint(appState.tr(.moreInfoAccessibilityHint))
            }
        }
    }

    private func propertyRows(for item: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            propertyRow(label: appState.tr(.kind), value: detailedProps?.kind ?? (item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased()))
            propertyRow(label: appState.tr(.size), value: item.formattedSize)
            if let dims = detailedProps?.dimensions {
                propertyRow(label: appState.tr(.dimensions), value: dims)
            }
            if let dur = detailedProps?.duration {
                propertyRow(label: appState.tr(.duration), value: dur)
            }
            propertyRow(label: appState.tr(.dateModified), value: item.formattedDate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func nativePreview(for item: FileItem) -> some View {
        if !item.isDirectory {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.tr(.codePreview))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                QLPreviewInlineView(url: item.url)
                    .frame(height: 220)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(6)
            }
        }
    }

    private func propertyRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            Text(value).font(.system(size: 12)).textSelection(.enabled).lineLimit(2)
        }
    }
}
