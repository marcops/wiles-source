import SwiftUI

struct DiskSpaceVisualizerSheetView: View {
    var appState: AppState
    @Environment(\.dismiss)
    private var dismiss
    @State private var report: DiskUsageReport?
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            headerView
            Divider()
            usageContentArea
            Divider()
            footerView
        }
        .padding(20)
        .frame(width: 500, height: 420)
        .onAppear {
            loadUsage()
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.tr(.diskUsageVisualizer))
                    .font(.system(size: 15, weight: .bold))
                Text(appState.navigation.currentURL.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let report {
                Text(report.formattedTotalSize)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
        }
    }

    @ViewBuilder
    private var footerView: some View {
        HStack {
            Spacer()
            Button(appState.tr(.close)) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    /// The `ScrollView` below is mounted unconditionally, from the very first render (while
    /// `isLoading` is still true), instead of being swapped in only after the async scan
    /// completes. A `ScrollView` inserted into an already-visible/key sheet window after the
    /// fact can fail to wire into the mouse-wheel/trackpad scroll responder chain until a
    /// resize forces AppKit to re-layout — see `UI_TEST_BACKLOG.md` for details. Keeping the
    /// `ScrollView` identity stable across the loading -> loaded transition avoids that class
    /// of bug entirely; only its inner content varies with state.
    @ViewBuilder
    private var usageContentArea: some View {
        VStack(spacing: 14) {
            if Self.shouldShowBarChart(isLoading: isLoading, report: report), let report {
                barChartView(report: report)
                Text(appState.tr(.topLargestItems))
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView {
                usageScrollContent
            }
            .frame(height: 220)
        }
    }

    /// Whether the summary bar chart + "Top Largest Items" label should be shown above the
    /// scroll area. Extracted as a pure, static function so the state-machine driving the
    /// fixed `ScrollView` mount above is independently unit-testable.
    static func shouldShowBarChart(isLoading: Bool, report: DiskUsageReport?) -> Bool {
        guard let report, !isLoading else { return false }
        return !report.topItems.isEmpty
    }

    @ViewBuilder
    private var usageScrollContent: some View {
        if isLoading {
            loadingIndicator
        } else if let report, !report.topItems.isEmpty {
            usageRowsList(report: report)
        } else {
            emptyStateView
        }
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Scanning folder size...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 220)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text(appState.tr(.folderIsEmpty))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 220)
    }

    @ViewBuilder
    private func usageRowsList(report: DiskUsageReport) -> some View {
        VStack(spacing: 6) {
            ForEach(report.topItems) { item in
                usageRow(item: item)
            }
            if let othersItem = report.othersItem {
                usageRow(item: othersItem)
            }
        }
    }

    @ViewBuilder
    private func barChartView(report: DiskUsageReport) -> some View {
        HStack(spacing: 2) {
            ForEach(report.topItems) { item in
                Rectangle()
                    .fill(Color(hue: item.colorHue, saturation: 0.7, brightness: 0.8))
                    .frame(height: 14)
            }
            if report.othersItem != nil {
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(height: 14)
            }
        }
        .cornerRadius(4)
    }

    private func loadUsage() {
        isLoading = true
        let current = appState.navigation.currentURL
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
            if item.isDirectory {
                appState.navigateTo(item.url)
                dismiss()
            }
        }
    }
}
