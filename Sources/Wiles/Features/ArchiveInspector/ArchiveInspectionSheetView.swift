import AppKit
import SwiftUI

struct ArchiveInspectionSheetView: View {
    private static let sheetWidth: CGFloat = 450.0
    private static let sheetHeight: CGFloat = 400.0

    let archiveURL: URL
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    /// The in-flight single-entry extractions, keyed by entry path, so closing the sheet cancels
    /// every `ditto`/`unzip` subprocess instead of letting them run to completion in the background.
    /// Keyed per-entry, not a single shared slot: each row's "Extract" button is its own
    /// independent action writing to its own destination file — a single shared slot silently
    /// cancelled one entry's in-flight extraction the moment a DIFFERENT entry's button was clicked.
    @State private var extractionTasks: [String: Task<Void, Never>] = [:]

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("doc.zipper"),
            title: archiveURL.lastPathComponent,
            width: Self.sheetWidth,
            height: Self.sheetHeight,
            primaryButton: ModalFooterButton(title: appState.tr(.close)) { dismiss() },
            content: { contentArea })
            .onDisappear { extractionTasks.values.forEach { $0.cancel() } }
    }

    private var contentArea: some View {
        AsyncResultView(
            operation: { try await ArchiveInspectionService.listEntries(in: archiveURL) },
            isEmpty: { $0.isEmpty },
            loading: { loadingView },
            empty: { emptyStateView },
            failure: { error in AsyncErrorStateView(message: appState.errorText(for: error)) },
            content: { entries in entriesList(entries) })
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text(appState.tr(.loadingEntries))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyStateView: some View {
        VStack {
            // An empty archive is a valid state, not an error — a neutral glyph, not a warning triangle.
            Image(systemName: "archivebox")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(appState.tr(.noArchiveEntriesFound))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func entriesList(_ entries: [ArchiveEntryItem]) -> some View {
        List {
            if entries.count >= ZIPCentralDirectoryReader.maxEntryCount {
                Text(String(format: appState.tr(.resultsTruncatedNotice), entries.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ForEach(entries) { entry in
                entryRow(entry)
            }
        }
    }

    private func entryRow(_ entry: ArchiveEntryItem) -> some View {
        HStack {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(entry.isDirectory ? .accentColor : .secondary)
                .accessibilityHidden(true)
            Text(entry.path)
                .font(.system(size: 12))
                .accessibilityLabel(entry.path)
                .accessibilityHint(entry.isDirectory ? appState.tr(.folder) : appState.tr(.archiveFileEntry))
            Spacer()
            if !entry.isDirectory {
                extractButton(for: entry)
            }
        }
    }

    private func extractButton(for entry: ArchiveEntryItem) -> some View {
        Button(appState.tr(.extractArchive)) {
            extractionTasks[entry.path]?.cancel()
            extractionTasks[entry.path] = Task {
                await extractEntry(entry)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(appState.tr(.extractArchive))
        .accessibilityHint(appState.tr(.extractEntryHint))
    }

    private func extractEntry(_ entry: ArchiveEntryItem) async {
        do {
            _ = try await ArchiveInspectionService.extractSingleEntry(from: archiveURL, entryPath: entry.path, to: appState.navigation.currentURL)
        } catch is CancellationError {
            // Sheet closed mid-extraction — the subprocess was terminated; nothing to surface.
            return
        } catch {
            await MainActor.run {
                appState.showError(error, context: "Extracting single archive entry")
            }
        }
        await MainActor.run {
            appState.refreshCurrentDirectory()
        }
    }
}
