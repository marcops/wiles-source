import SwiftUI
import AppKit

struct ArchiveInspectionSheetView: View {
    let archiveURL: URL
    var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ArchiveEntryItem] = []

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
            
            if entries.isEmpty {
                VStack {
                    ProgressView()
                    Text("Loading entries...")
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
                                do {
                                    _ = try ArchiveInspectionService.extractSingleEntry(from: archiveURL, entryPath: entry.path, to: appState.currentURL)
                                } catch {
                                    appState.showError(error.localizedDescription)
                                }
                                appState.refreshCurrentDirectory()
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
        .onAppear {
            entries = ArchiveInspectionService.listEntries(in: archiveURL)
        }
    }
}
