import Foundation
@testable import Wiles

@MainActor
public struct ListColumnTests {
    public static func run() {
        let appState = AppState()
        testDefaultColumnState(appState: appState)
        testColumnVisibilityToggling(appState: appState)
        testColumnWidthResizing(appState: appState)
        testColumnAutoFitting(appState: appState)
        testVisibleColumnsReflectsVisibilityState(appState: appState)
    }

    /// B15-4: `FileListView` now resolves `FileListHeaderView.visibleColumns` once per container
    /// render (was once per visible row). Pin that it still equals the visible subset of columns.
    private static func testVisibleColumnsReflectsVisibilityState(appState: AppState) {
        appState.preferences.view.listColumnStates = ListColumnState.defaults()
        let allVisible = FileListHeaderView.visibleColumns(appState)
        report(
            "UI/ListColumns",
            "POS: visibleColumns lists exactly the currently-visible columns in ListColumn order",
            result: allVisible == ListColumn.allCases.filter { appState.isColumnVisible($0) })

        appState.toggleColumnVisibility(.size)
        report(
            "UI/ListColumns",
            "POS: hiding a column drops it from visibleColumns but keeps Name",
            result: !FileListHeaderView.visibleColumns(appState).contains(.size)
                && FileListHeaderView.visibleColumns(appState).contains(.name))
        appState.toggleColumnVisibility(.size)
    }

    private static func testDefaultColumnState(appState: AppState) {
        appState.preferences.view.listColumnStates = ListColumnState.defaults()
        report("UI/ListColumns", "POS: Name column remains visible by default", result: appState.isColumnVisible(.name))
    }

    private static func testColumnVisibilityToggling(appState: AppState) {
        appState.preferences.view.listColumnStates = ListColumnState.defaults()
        appState.toggleColumnVisibility(.name)
        report("UI/ListColumns", "POS: Name column cannot be toggled off", result: appState.isColumnVisible(.name))

        appState.toggleColumnVisibility(.size)
        report("UI/ListColumns", "POS: Size column toggles to hidden", result: !appState.isColumnVisible(.size))
        appState.toggleColumnVisibility(.size)
        report("UI/ListColumns", "POS: Size column toggles back to visible", result: appState.isColumnVisible(.size))
    }

    private static func testColumnWidthResizing(appState: AppState) {
        appState.preferences.view.listColumnStates = ListColumnState.defaults()
        appState.setColumnWidth(.dateModified, width: 220)
        report("UI/ListColumns", "POS: Column width for Date Modified updated to 220", result: appState.columnWidth(for: .dateModified) == 220)

        appState.setColumnWidth(.kind, width: 30)
        report("UI/ListColumns", "POS: Column width clamped to minimum 60pt", result: appState.columnWidth(for: .kind) == 60)
    }

    private static func testColumnAutoFitting(appState: AppState) {
        appState.preferences.view.listColumnStates = ListColumnState.defaults()
        appState.setColumnWidth(.name, width: 60)
        appState.autoFitColumnWidth(.name)
        let autoWidth = appState.columnWidth(for: .name)
        report("UI/ListColumns", "POS: Auto-fitting name column adjusts width above minimum", result: autoWidth >= LayoutTokens.columnMinWidth)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
