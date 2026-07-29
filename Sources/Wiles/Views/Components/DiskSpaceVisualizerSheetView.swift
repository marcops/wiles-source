import SwiftUI

struct DiskSpaceVisualizerSheetView: View {
    var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var report: DiskUsageReport? = nil
    @State private var isLoading: Bool = true
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.tr(.diskUsageVisualizer))
                        .font(.system(size: 15, weight: .bold))
                    Text(appState.currentURL.path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let r = report {
                    Text(r.formattedTotalSize)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
            }
            
            Divider()
            
            if isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Scanning folder size...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 260)
            } else if let r = report, !r.topItems.isEmpty {
                VStack(spacing: 14) {
                    HStack(spacing: 2) {
                        ForEach(r.topItems) { item in
                            Rectangle()
                                .fill(Color(hue: item.colorHue, saturation: 0.7, brightness: 0.8))
                                .frame(height: 14)
                        }
                        if let _ = r.othersItem {
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(height: 14)
                        }
                    }
                    .cornerRadius(4)
                    
                    Text(appState.tr(.topLargestItems))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(r.topItems) { item in
                                usageRow(item: item)
                            }
                            if let oth = r.othersItem {
                                usageRow(item: oth)
                            }
                        }
                    }
                    .frame(height: 220)
                }
            } else {
                VStack {
                    Spacer()
                    Text(appState.tr(.folderIsEmpty))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 260)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button(appState.tr(.close)) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500, height: 420)
        .onAppear {
            loadUsage()
        }
    }
    
    private func loadUsage() {
        isLoading = true
        let current = appState.currentURL
        Task {
            let res = await DiskSpaceVisualizerService.calculateDiskUsage(for: current)
            await MainActor.run {
                self.report = res
                self.isLoading = false
            }
        }
    }
    
    @ViewBuilder
    private func usageRow(item: DiskUsageItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(item.colorHue == 0.0 ? Color.gray : Color(hue: item.colorHue, saturation: 0.7, brightness: 0.8))
                .frame(width: 10, height: 10)
            
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                .font(.system(size: 12))
            
            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(String(format: "%.1f%%", item.percentage))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            Text(item.formattedSize)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if item.isDirectory && FileManager.default.fileExists(atPath: item.url.path) {
                appState.navigateTo(item.url)
                dismiss()
            }
        }
    }
}
