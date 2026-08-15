import SwiftUI
import AppKit
import GitBeacon

struct ArchiveInspectionSheetView: View {
    let archiveURL: URL
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    @State private var entries: [ArchiveEntryItem] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 12) {
            headerView

            Divider()

            contentArea

            Divider()

            footerView
        }
        .padding()
        .frame(width: LayoutTokens.archiveInspectionSheetWidth, height: LayoutTokens.archiveInspectionSheetHeight)
        .task {
            entries = await ArchiveInspectionService.listEntries(in: archiveURL)
            isLoading = false
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "doc.zipper")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(archiveURL.lastPathComponent)
                .font(.headline)
            Spacer()
        }
    }

    @ViewBuilder private var contentArea: some View {
        if isLoading {
            loadingView
        } else if entries.isEmpty {
            emptyStateView
        } else {
            entriesList
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text(appState.tr(.loadingEntries))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(appState.tr(.noArchiveEntriesFound))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var entriesList: some View {
        List(entries) { entry in
            entryRow(entry)
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
            Task {
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
        } catch {
            ErrorReporter.report(error, context: "Extracting single archive entry")
            await MainActor.run {
                appState.showError(error.localizedDescription)
            }
        }
        await MainActor.run {
            appState.refreshCurrentDirectory()
        }
    }

    private var footerView: some View {
        HStack {
            Spacer()
            Button(appState.tr(.close)) {
                dismiss()
            }
        }
    }
}
