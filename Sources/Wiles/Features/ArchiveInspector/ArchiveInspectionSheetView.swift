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
                    Text("Loading entries...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else if entries.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No entries found or the archive could not be read.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    HStack {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundColor(entry.isDirectory ? .accentColor : .secondary)
                        Text(entry.path)
                            .font(.system(size: 12))
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
        .frame(width: 450, height: 400)
        .task {
            entries = await ArchiveInspectionService.listEntries(in: archiveURL)
            isLoading = false
        }
    }
}
