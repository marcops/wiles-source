import SwiftUI
import AppKit

struct ArchiveInspectionSheetView: View {
    let archiveURL: URL
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    @State private var entries: [ArchiveEntryItem] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.zipper")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(archiveURL.lastPathComponent)
                    .font(.headline)
                Spacer()
            }

            Divider()

            if isLoading {
                VStack {
                    ProgressView()
                    Text(appState.tr(.loadingEntries))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else if entries.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(appState.tr(.noArchiveEntriesFound))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(entries) { entry in
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
                            Button(appState.tr(.extractArchive)) {
                                Task {
                                    do {
                                        _ = try await ArchiveInspectionService.extractSingleEntry(from: archiveURL, entryPath: entry.path, to: appState.navigation.currentURL)
                                    } catch {
                                        await MainActor.run {
                                            appState.showError(error.localizedDescription)
                                        }
                                    }
                                    await MainActor.run {
                                        appState.refreshCurrentDirectory()
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel(appState.tr(.extractArchive))
                            .accessibilityHint(appState.tr(.extractEntryHint))
                        }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(appState.tr(.close)) {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: LayoutTokens.archiveInspectionSheetWidth, height: LayoutTokens.archiveInspectionSheetHeight)
        .task {
            entries = await ArchiveInspectionService.listEntries(in: archiveURL)
            isLoading = false
        }
    }
}
