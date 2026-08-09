import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct ICloudStatusBadgeView: View {
    let item: FileItem

    public init(item: FileItem) {
        self.item = item
    }

    public var body: some View {
        if item.isUbiquitousDownloading {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 14, height: 14)
        } else if item.isUbiquitousNotDownloaded {
            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentColor)
        } else if item.isUbiquitousUploading {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

extension AppState {
    public func handleSelection(for item: FileItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selectedURLs.contains(item.url) {
                selectedURLs.remove(item.url)
            } else {
                selectedURLs.insert(item.url)
            }
        } else if flags.contains(.shift),
            let last = selectedURLs.first,
            let lastIdx = fileSystem.items.firstIndex(where: { $0.url == last }),
            let curIdx = fileSystem.items.firstIndex(where: { $0.url == item.url }) {
            let range = min(lastIdx, curIdx)...max(lastIdx, curIdx)
            let rangeURLs = fileSystem.items[range].map { $0.url }
            selectedURLs.formUnion(rangeURLs)
        } else {
            selectedURLs = [item.url]
        }
    }

    public func handleDrop(providers: [NSItemProvider], targetFolder: URL) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { droppedURL, _ in
                guard let droppedURL = droppedURL, droppedURL.standardizedFileURL != targetFolder.standardizedFileURL else { return }
                Task { @MainActor in
                    do {
                        _ = try FileSystemService.moveItem(at: droppedURL, toFolder: targetFolder)
                        self.refreshCurrentDirectory()
                    } catch {
                        self.showError(error)
                    }
                }
            }
        }
    }
}

public func colorForTag(_ tag: String) -> Color {
    switch tag.lowercased() {
    case "red": return .red
    case "orange": return .orange
    case "yellow": return .yellow
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "gray", "grey": return .gray
    default: return .secondary
    }
}
