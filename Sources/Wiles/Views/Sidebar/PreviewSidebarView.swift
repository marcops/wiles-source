import SwiftUI
import AppKit

struct PreviewSidebarView: View {
    var appState: AppState
    @State private var detailedProps: DetailedFileProperties?
    @State private var previewContent: String?

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
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .sidebar)
                Color(NSColor.windowBackgroundColor)
                    .opacity(1.0 - Double(appState.preferences.translucentLevel) / 100.0)
            }
        )
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
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)

                Text(item.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Divider()

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

                if !item.isDirectory, let content = previewContent {
                    let ext = item.fileExtension.lowercased()
                    if ["swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "md", "txt"].contains(ext) {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.tr(.codePreview))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            ScrollView(.vertical) {
                                Text(SyntaxHighlighterService.highlightCode(content: content, fileExtension: ext))
                                    .font(.system(size: 10, design: .monospaced))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(6)
                            }
                            .frame(maxHeight: 160)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                            .cornerRadius(6)
                        }
                    }
                }

                Spacer()

                Button(appState.tr(.moreInfo)) {
                    appState.propertiesItem = item
                }
                .buttonStyle(.link)
            }
            .task(id: item.url) {
                previewContent = item.isDirectory ? nil : await Self.loadPreviewContent(url: item.url)
            }
        }
    }

    private static func loadPreviewContent(url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {
            guard let content = try? String(contentsOf: url), content.count < 1_000_000 else { return nil }
            return content
        }.value
    }

    private func propertyRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            Text(value).font(.system(size: 12)).textSelection(.enabled).lineLimit(2)
        }
    }
}
