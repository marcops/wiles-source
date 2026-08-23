import Charts
import SwiftUI

struct DiskUsageSidebarView: View {
    var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            contentArea
        }
        .padding()
        .frame(minWidth: 240, idealWidth: 270, maxWidth: 360, maxHeight: .infinity)
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .sidebar)
                Color(NSColor.windowBackgroundColor)
                    .opacity(1.0 - Double(appState.preferences.translucentLevel) / 100.0)
            })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.accentColor)
                Text(appState.tr(.actDiskVisualizer))
                    .font(.system(size: 13, weight: .bold))
            }
            Text(appState.navigation.currentURL.lastPathComponent)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    /// The `ScrollView` stays mounted with a stable identity across the loading -> loaded
    /// transition (only its inner content varies) — a `ScrollView` inserted into an
    /// already-visible sidebar after the fact can fail to wire into the mouse-wheel/trackpad
    /// scroll responder chain until a resize forces AppKit to re-layout. See UI_TEST_BACKLOG.md.
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AsyncResultView(
                    id: appState.navigation.currentURL,
                    operation: { await DiskSpaceVisualizerService.calculateDiskUsage(for: appState.navigation.currentURL) },
                    isEmpty: { $0.topItems.isEmpty },
                    loading: { loadingIndicator },
                    empty: { emptyStateView },
                    content: { report in
                        donutChart(report: report)
                        Text(appState.tr(.topLargestItems))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        itemsList(report: report)
                    })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func donutChart(report: DiskUsageReport) -> some View {
        Chart {
            ForEach(report.topItems) { item in
                SectorMark(angle: .value(item.name, item.size), innerRadius: .ratio(0.62), angularInset: 1.5)
                    .foregroundStyle(colorFor(item))
                    .cornerRadius(3)
            }
            if let others = report.othersItem {
                SectorMark(angle: .value(others.name, others.size), innerRadius: .ratio(0.62), angularInset: 1.5)
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .cornerRadius(3)
            }
        }
        .chartLegend(.hidden)
        .frame(height: 110)
        .overlay {
            Text(report.isApproximate ? "~\(report.formattedTotalSize)" : report.formattedTotalSize)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
        }
    }

    private func itemsList(report: DiskUsageReport) -> some View {
        VStack(spacing: 6) {
            ForEach(report.topItems) { item in
                itemRow(item: item)
            }
            if let othersItem = report.othersItem {
                itemRow(item: othersItem)
            }
        }
    }

    private func itemRow(item: DiskUsageItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorFor(item))
                .frame(width: 9, height: 9)
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                .font(.system(size: 11))
            Text(item.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.formattedSize)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if item.isDirectory {
                appState.navigateTo(item.url)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(item.name)
        .accessibilityHint(appState.tr(.diskUsageItemNavigateHint))
    }

    private func colorFor(_ item: DiskUsageItem) -> Color {
        item.colorHue == 0.0 ? Color.gray.opacity(0.5) : Color(hue: item.colorHue, saturation: 0.7, brightness: 0.8)
    }

    private var loadingIndicator: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text(appState.tr(.folderIsEmpty))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}
