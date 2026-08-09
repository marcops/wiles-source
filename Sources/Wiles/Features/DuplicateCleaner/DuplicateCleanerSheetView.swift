import SwiftUI

public struct DuplicateCleanerSheetView: View {
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss

    @State private var isScanning = true
    @State private var scanResult: DuplicateScanResult?
    @State private var selectedURLsToTrash: Set<URL> = []

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if isScanning {
                scanningView
            } else if let result = scanResult, !result.groups.isEmpty {
                resultsView(result: result)
            } else {
                emptyView
            }

            Divider()
            footerBar
        }
        .frame(width: 640, height: 480)
        .task {
            let res = await DuplicateDetectionService.shared.findDuplicates(in: appState.navigation.currentURL)
            self.scanResult = res
            var autoSelect: Set<URL> = []
            for group in res.groups {
                for item in group.items.dropFirst() {
                    autoSelect.insert(item.url)
                }
            }
            self.selectedURLsToTrash = autoSelect
            self.isScanning = false
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.doc.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.tr(.duplicateCleanerTitle))
                    .font(.headline)
                Text(appState.tr(.duplicateCleanerSubtitle))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(appState.tr(.scanningFolderSize))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text(appState.tr(.noDuplicatesFound))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func resultsView(result: DuplicateScanResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(appState.tr(.reclaimableSpace) + ": ")
                    .foregroundColor(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: result.totalReclaimableBytes, countStyle: .file))
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(result.groups) { group in
                        duplicateGroupCard(group: group)
                    }
                }
                .padding(16)
            }
        }
    }

    private func duplicateGroupCard(group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ByteCountFormatter.string(fromByteCount: group.fileSize, countStyle: .file))
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(4)
                Spacer()
            }

            ForEach(group.items) { item in
                duplicateItemRow(item)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private func duplicateItemRow(_ item: FileItem) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { selectedURLsToTrash.contains(item.url) },
                set: { isChecked in
                    if isChecked { selectedURLsToTrash.insert(item.url) } else { selectedURLsToTrash.remove(item.url) }
                }
            ))
            .labelsHidden()

            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 16, height: 16)

            Text(item.url.path)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }

    private var footerBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Text(appState.tr(.cancel))
            }
            .keyboardShortcut(.cancelAction)

            Button {
                trashSelected()
                dismiss()
            } label: {
                Text(appState.tr(.trashSelectedDuplicates))
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedURLsToTrash.isEmpty)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private func trashSelected() {
        let urls = Array(selectedURLsToTrash)
        Task.detached(priority: .userInitiated) {
            var failureCount = 0
            for fileURL in urls {
                do {
                    _ = try FileSystemService.moveToTrash(url: fileURL)
                } catch {
                    failureCount += 1
                }
            }
            await MainActor.run {
                DirectoryCacheService.shared.invalidate(url: appState.navigation.currentURL)
                appState.refreshCurrentDirectory()
                if failureCount > 0 {
                    appState.showError(WilesError.operationFailed(reason: "\(failureCount) of \(urls.count) items could not be moved to Trash.").localizedDescription)
                }
            }
        }
    }
}
