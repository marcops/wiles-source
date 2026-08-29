import AppKit
import SwiftUI

struct PreviewSidebarView: View {
    private static let minWidth: CGFloat = 200
    private static let idealWidth: CGFloat = 250
    private static let maxWidth: CGFloat = 350

    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var detailedProps: DetailedFileProperties?
    @State private var resolvedItem: FileItem?

    var body: some View {
        ScrollView {
            VStack {
                if appState.selection.selectedURLs.isEmpty {
                    Text(appState.tr(.noSelection)).foregroundColor(.secondary)
                } else if appState.selection.selectedURLs.count == 1 {
                    singleSelectionView
                } else {
                    Text("\(appState.selection.selectedURLs.count) \(appState.tr(.itemsSelectedSuffix))").foregroundColor(.secondary)
                }
            }
            .frame(minWidth: Self.minWidth, idealWidth: Self.idealWidth, maxWidth: Self.maxWidth)
        }
        .frame(minWidth: Self.minWidth, idealWidth: Self.idealWidth, maxWidth: Self.maxWidth, maxHeight: .infinity)
        .padding()
        .translucentBackground(material: .sidebar, opacity: appState.preferences.appearance.sidebarOverlayOpacity)
        .task(id: appState.selection.selectedURLs) {
            detailedProps = nil
            resolvedItem = nil
            guard let first = appState.selection.selectedURLs.first, appState.selection.selectedURLs.count == 1 else { return }
            resolvedItem = appState.fileSystem.items.first { $0.url.standardizedFileURL == first.standardizedFileURL }
            detailedProps = await FileMetadataService.shared.fetchProperties(for: first)
        }
    }

    @ViewBuilder private var singleSelectionView: some View {
        if let item = resolvedItem {
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
                    windowUIState.activeModal = .properties(item)
                }
                .buttonStyle(.link)
                .accessibilityLabel(appState.tr(.moreInfo))
                .accessibilityHint(appState.tr(.moreInfoAccessibilityHint))
            }
        } else {
            Text(appState.tr(.previewUnavailable)).foregroundColor(.secondary)
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
            propertyRow(label: appState.tr(.dateModified), value: item.formattedDate(language: appState.preferences.appearance.appLanguage))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func nativePreview(for item: FileItem) -> some View {
        if !item.isDirectory {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.tr(.preview))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                QLPreviewInlineView(url: item.url, appState: appState)
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
