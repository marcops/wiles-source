import SwiftUI

public struct DuplicateCleanerSheetView: View {
    var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var isScanning = true
    @State private var scanResult: DuplicateScanResult? = nil
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
            let res = await DuplicateDetectionService.shared.findDuplicates(in: appState.currentURL)
            self.scanResult = res
            var autoSelect: Set<URL> = []
            for g in res.groups {
                for item in g.items.dropFirst() {
                    autoSelect.insert(item.url)
                }
            }
            self.selectedURLsToTrash = autoSelect
            self.isScanning = false
        }
    }
    
    private var headerBar: some View {
        HStack {
            Image(systemName: "doc.on.doc.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 16))
            Text(appState.tr(.duplicateCleanerTitle))
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
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
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { selectedURLsToTrash.contains(item.url) },
                        set: { isChecked in
                            if isChecked { selectedURLsToTrash.insert(item.url) }
                            else { selectedURLsToTrash.remove(item.url) }
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
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
    
    private var footerBar: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Text(appState.tr(.cancel))
            }
            .keyboardShortcut(.cancelAction)
            
            Button(action: {
                trashSelected()
                dismiss()
            }) {
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
        Task { @MainActor in
            for u in urls {
                _ = try? FileSystemService.moveToTrash(url: u)
            }
            DirectoryCacheService.shared.invalidate(url: appState.currentURL)
            appState.refreshCurrentDirectory()
        }
    }
}
