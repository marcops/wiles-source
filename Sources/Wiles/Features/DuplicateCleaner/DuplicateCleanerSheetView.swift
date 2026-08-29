import GitBeacon
import SwiftUI

public struct DuplicateCleanerSheetView: View {
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss

    @State private var selectedURLsToTrash: Set<URL> = []
    @State private var isTrashing = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ModalScaffoldView(
            icon: .symbol("doc.on.doc.fill"),
            title: appState.tr(.duplicateCleanerTitle),
            subtitle: appState.tr(.duplicateCleanerSubtitle),
            width: 640,
            height: 480,
            primaryButton: ModalFooterButton(
                title: isTrashing ? appState.tr(.movingToTrashEllipsis) : appState.tr(.moveToTrash),
                isEnabled: !selectedURLsToTrash.isEmpty && !isTrashing) {
                    isTrashing = true
                    trashSelected()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { mainContent })
    }

    private var mainContent: some View {
        AsyncResultView(
            operation: {
                let res = try await DuplicateDetectionService.findDuplicates(in: appState.navigation.currentURL)
                selectedURLsToTrash = Set(res.groups.flatMap { $0.items.dropFirst().map(\.url) })
                return res
            },
            isEmpty: { $0.groups.isEmpty },
            loading: { scanningView },
            empty: { emptyView },
            failure: { error in AsyncErrorStateView(message: appState.errorText(for: error)) },
            content: { result in resultsView(result: result) })
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
            resultsHeader(result: result)

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

    private func resultsHeader(result: DuplicateScanResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(appState.tr(.reclaimableSpace) + ": ")
                    .foregroundColor(.secondary)
                Text(ByteFormat.fileSize(result.totalReclaimableBytes))
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            Text(appState.tr(.duplicateKeepFirstCopyNotice))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            if result.wasTruncated {
                Text(appState.tr(.duplicateScanTruncatedNotice))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
        }
    }

    private func duplicateGroupCard(group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ByteFormat.fileSize(group.fileSize))
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
                    if isChecked {
                        selectedURLsToTrash.insert(item.url)
                    } else {
                        selectedURLsToTrash.remove(item.url)
                    }
                }))
                .labelsHidden()
                .accessibilityLabel("\(appState.tr(.moveToTrash)): \(item.url.lastPathComponent)")

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

    private func trashSelected() {
        let urls = Array(selectedURLsToTrash)
        Task.detached(priority: .userInitiated) {
            var failureCount = 0
            for fileURL in urls {
                do {
                    _ = try await FileSystemService.moveToTrash(url: fileURL)
                } catch {
                    ErrorReporter.report(error, context: "Moving duplicate file to Trash")
                    failureCount += 1
                }
            }
            await MainActor.run {
                DirectoryCacheService.shared.invalidate(url: appState.navigation.currentURL)
                appState.refreshCurrentDirectory()
                if failureCount > 0 {
                    let reason = String(format: appState.tr(.moveToTrashPartialFailure), failureCount, urls.count)
                    appState.showError(WilesError.operationFailed(reason: reason))
                }
                dismiss()
            }
        }
    }
}
