import Foundation
@testable import Wiles

@MainActor
public struct ListColumnSettingsTests {
    public static func run() {
        testListColumnDefaults()
        testListColumnDefaultWidths()
        testListColumnStateCodableRoundTrip()
    }

    private static func testListColumnDefaults() {
        let defaults = ListColumnState.defaults()
        let allColumns = Set(ListColumn.allCases)
        let defaultColumns = Set(defaults.map(\.column))
        report(
            "Model/ListColumnSettings",
            "POS: defaults() returns exactly one entry per ListColumn case",
            result: defaults.count == ListColumn.allCases.count && defaultColumns == allColumns)

        let initiallyVisible: Set<ListColumn> = [.name, .size, .dateModified]
        let actualVisible = Set(defaults.filter(\.isVisible).map(\.column))
        report(
            "Model/ListColumnSettings",
            "POS: defaults() marks exactly name/size/dateModified as initially visible",
            result: actualVisible == initiallyVisible)

        let hidden = defaults.filter { !$0.isVisible }.map(\.column)
        let hiddenSet = Set(hidden)
        let expectedHidden: Set<ListColumn> = [.dateCreated, .dateAccessed, .kind, .owner, .group]
        report("Model/ListColumnSettings", "NEG: defaults() leaves the remaining columns hidden", result: hiddenSet == expectedHidden)

        report("Model/ListColumnSettings", "POS: Name column is always visible per isAlwaysVisible", result: ListColumn.name.isAlwaysVisible)
        report(
            "Model/ListColumnSettings",
            "NEG: non-name columns report isAlwaysVisible as false",
            result: ListColumn.allCases.filter { $0 != .name }.allSatisfy { !$0.isAlwaysVisible })

        // POS: Identifiable.id mirrors rawValue exactly for every case (used by SwiftUI ForEach/Picker).
        report(
            "Model/ListColumnSettings",
            "POS: ListColumn.id equals rawValue for every case",
            result: ListColumn.allCases.allSatisfy { $0.id == $0.rawValue })
    }

    private static func testListColumnDefaultWidths() {
        let defaults = ListColumnState.defaults()
        let withinBounds = defaults.allSatisfy { state in
            state.column == .name || (state.width >= LayoutTokens.columnMinWidth && state.width <= ColumnAutoFitService.columnMaxWidth)
        }
        report("Model/ListColumnSettings", "POS: default widths for fixed-width columns fall within columnMinWidth...columnMaxWidth", result: withinBounds)

        let widthsMatch = defaults.allSatisfy { $0.width == $0.column.defaultWidth }
        report("Model/ListColumnSettings", "POS: each default state's width matches its column's defaultWidth", result: widthsMatch)

        report(
            "Model/ListColumnSettings",
            "NEG: name column's defaultWidth (280) is not clamped to columnMinWidth like other small values would be",
            result: ListColumn.name.defaultWidth == 280 && ListColumn.name.defaultWidth != LayoutTokens.columnMinWidth)
    }

    private static func testListColumnStateCodableRoundTrip() {
        let state = ListColumnState(column: .kind, width: 145, isVisible: true)
        do {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(ListColumnState.self, from: data)
            let matches = decoded.column == state.column && decoded.width == state.width && decoded.isVisible == state.isVisible
            report("Model/ListColumnSettings", "POS: ListColumnState JSON encode/decode round-trip preserves column, width, isVisible", result: matches)
        } catch {
            report("Model/ListColumnSettings", "POS: ListColumnState JSON encode/decode round-trip preserves column, width, isVisible", result: false)
        }

        do {
            let array = ListColumnState.defaults()
            let data = try JSONEncoder().encode(array)
            let decodedArray = try JSONDecoder().decode([ListColumnState].self, from: data)
            report(
                "Model/ListColumnSettings",
                "POS: full defaults() array survives JSON round-trip with matching count and order",
                result: decodedArray.map(\.column) == array.map(\.column))
        } catch {
            report("Model/ListColumnSettings", "POS: full defaults() array survives JSON round-trip with matching count and order", result: false)
        }

        do {
            let data = Data("{\"column\":\"Not A Column\",\"width\":50,\"isVisible\":true}".utf8)
            _ = try JSONDecoder().decode(ListColumnState.self, from: data)
            report("Model/ListColumnSettings", "NEG: ListColumnState fails to decode when column raw value is unrecognized", result: false)
        } catch {
            report("Model/ListColumnSettings", "NEG: ListColumnState fails to decode when column raw value is unrecognized", result: true)
        }
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
