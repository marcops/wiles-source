@testable import Wiles
import Foundation

// Covers `DiskSpaceVisualizerSheetView.shouldShowBarChart(isLoading:report:)`, the pure
// state-machine function that decides whether the summary bar chart + label are shown above
// the `ScrollView`. This function is what lets the `ScrollView` stay mounted with a stable
// identity across the loading -> loaded transition (see the fix for the "mouse/trackpad scroll
// doesn't work inside Disk Usage" bug: a `ScrollView` inserted into an already-visible sheet
// window after an async load can fail to wire into the scroll responder chain). The real
// AppKit scroll-wheel responder-chain behavior itself isn't unit-testable here — see
// UI_TEST_BACKLOG.md.
@MainActor
public struct DiskSpaceVisualizerSheetViewTests {
    public static func run() {
        testHiddenWhileLoadingEvenWithReport()
        testHiddenWhenReportIsNil()
        testHiddenWhenReportHasNoTopItems()
        testShownOnceLoadedWithItems()
    }

    private static func sampleReport(topItems: [DiskUsageItem]) -> DiskUsageReport {
        DiskUsageReport(totalSize: 1024, topItems: topItems, othersItem: nil)
    }

    private static func sampleItem() -> DiskUsageItem {
        let tempURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("item.bin")
        return DiskUsageItem(url: tempURL, name: "item.bin", size: 1024, percentage: 100, isDirectory: false, colorHue: 0.5)
    }

    // NEG: even if a report already exists, the bar chart must stay hidden while still loading
    private static func testHiddenWhileLoadingEvenWithReport() {
        let usageReport = sampleReport(topItems: [sampleItem()])
        let result = DiskSpaceVisualizerSheetView.shouldShowBarChart(isLoading: true, report: usageReport)
        logResult("NEG: bar chart stays hidden while isLoading is true, even with a populated report", result: !result)
    }

    // NEG: no report yet (nil) means no bar chart
    private static func testHiddenWhenReportIsNil() {
        let result = DiskSpaceVisualizerSheetView.shouldShowBarChart(isLoading: false, report: nil)
        logResult("NEG: bar chart stays hidden when report is nil", result: !result)
    }

    // NEG: an empty folder's report has no topItems, so no bar chart
    private static func testHiddenWhenReportHasNoTopItems() {
        let result = DiskSpaceVisualizerSheetView.shouldShowBarChart(isLoading: false, report: sampleReport(topItems: []))
        logResult("NEG: bar chart stays hidden when report.topItems is empty", result: !result)
    }

    // POS: loading finished, report has items -> bar chart shows
    private static func testShownOnceLoadedWithItems() {
        let result = DiskSpaceVisualizerSheetView.shouldShowBarChart(isLoading: false, report: sampleReport(topItems: [sampleItem()]))
        logResult("POS: bar chart shows once loading finishes and report has items", result: result)
    }

    private static func logResult(_ name: String, result: Bool) {
        TestReporter.report("Feature/DiskSpaceVisualizerSheetView", name, result: result)
    }
}
