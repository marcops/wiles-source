@testable import Wiles
import Foundation

@MainActor
public struct AutoOrganizationRuleAndListColumnTests {
    public static func run() {
        testRuleCodableRoundTrip()
        testRuleDefaultIsEnabled()
        testRuleIdentityIsUniquePerInstance()
        testRuleConditionTypeCases()
        testListColumnDefaults()
        testListColumnStateCodableRoundTrip()
        testListColumnDefaultWidths()
    }

    // MARK: - AutoOrganizationRule

    private static func testRuleCodableRoundTrip() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = dir.appendingPathComponent("Source")
        let destination = dir.appendingPathComponent("Destination")

        let rule = AutoOrganizationRule(
            id: UUID(),
            sourceURL: source,
            destinationURL: destination,
            conditionType: .extensionEquals,
            conditionValue: "pdf",
            isEnabled: false
        )

        do {
            let data = try JSONEncoder().encode(rule)
            let decoded = try JSONDecoder().decode(AutoOrganizationRule.self, from: data)
            let matches = decoded.id == rule.id
                && decoded.sourceURL == rule.sourceURL
                && decoded.destinationURL == rule.destinationURL
                && decoded.conditionType == rule.conditionType
                && decoded.conditionValue == rule.conditionValue
                && decoded.isEnabled == rule.isEnabled
            report("AutoOrganizationRule", "POS: JSON encode/decode round-trip preserves all fields exactly", result: matches)
        } catch {
            report("AutoOrganizationRule", "POS: JSON encode/decode round-trip preserves all fields exactly", result: false)
        }
    }

    private static func testRuleDefaultIsEnabled() {
        let rule = AutoOrganizationRule(
            sourceURL: URL(fileURLWithPath: NSTemporaryDirectory()),
            destinationURL: URL(fileURLWithPath: NSTemporaryDirectory()),
            conditionType: .nameContains,
            conditionValue: "invoice"
        )
        report("AutoOrganizationRule", "POS: default initializer sets isEnabled to true when omitted", result: rule.isEnabled == true)
    }

    private static func testRuleIdentityIsUniquePerInstance() {
        let source = URL(fileURLWithPath: NSTemporaryDirectory())
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
        let ruleA = AutoOrganizationRule(sourceURL: source, destinationURL: destination, conditionType: .namePrefix, conditionValue: "IMG")
        let ruleB = AutoOrganizationRule(sourceURL: source, destinationURL: destination, conditionType: .namePrefix, conditionValue: "IMG")
        report("AutoOrganizationRule", "NEG: two independently-constructed rules with identical fields get distinct auto-generated ids", result: ruleA.id != ruleB.id)

        let fixedID = UUID()
        let ruleC = AutoOrganizationRule(id: fixedID, sourceURL: source, destinationURL: destination, conditionType: .namePrefix, conditionValue: "IMG")
        let ruleD = AutoOrganizationRule(id: fixedID, sourceURL: source, destinationURL: destination, conditionType: .namePrefix, conditionValue: "IMG")
        report("AutoOrganizationRule", "POS: rules constructed with the same explicit id compare equal (Hashable/Equatable via memberwise synthesis)", result: ruleC == ruleD && ruleC.id == ruleD.id)
    }

    private static func testRuleConditionTypeCases() {
        let allCases = RuleConditionType.allCases
        let uniqueIDs = Set(allCases.map { $0.id })
        report("AutoOrganizationRule", "POS: RuleConditionType.allCases has 3 cases with unique ids matching their raw values", result: allCases.count == 3 && uniqueIDs.count == 3 && allCases.allSatisfy { $0.id == $0.rawValue })

        do {
            let data = try JSONEncoder().encode(RuleConditionType.extensionEquals)
            let decoded = try JSONDecoder().decode(RuleConditionType.self, from: data)
            report("AutoOrganizationRule", "POS: RuleConditionType Codable round-trip preserves case", result: decoded == .extensionEquals)
        } catch {
            report("AutoOrganizationRule", "POS: RuleConditionType Codable round-trip preserves case", result: false)
        }

        do {
            let data = "\"Not A Real Condition\"".data(using: .utf8)!
            _ = try JSONDecoder().decode(RuleConditionType.self, from: data)
            report("AutoOrganizationRule", "NEG: RuleConditionType fails to decode an unrecognized raw value", result: false)
        } catch {
            report("AutoOrganizationRule", "NEG: RuleConditionType fails to decode an unrecognized raw value", result: true)
        }
    }

    // MARK: - ListColumnState / ListColumn

    private static func testListColumnDefaults() {
        let defaults = ListColumnState.defaults()
        let allColumns = Set(ListColumn.allCases)
        let defaultColumns = Set(defaults.map { $0.column })
        report("ListColumnSettings", "POS: defaults() returns exactly one entry per ListColumn case", result: defaults.count == ListColumn.allCases.count && defaultColumns == allColumns)

        let initiallyVisible: Set<ListColumn> = [.name, .size, .dateModified]
        let actualVisible = Set(defaults.filter { $0.isVisible }.map { $0.column })
        report("ListColumnSettings", "POS: defaults() marks exactly name/size/dateModified as initially visible", result: actualVisible == initiallyVisible)

        let hidden = defaults.filter { !$0.isVisible }.map { $0.column }
        let hiddenSet = Set(hidden)
        let expectedHidden: Set<ListColumn> = [.dateCreated, .dateAccessed, .kind, .owner, .group]
        report("ListColumnSettings", "NEG: defaults() leaves the remaining columns hidden", result: hiddenSet == expectedHidden)

        report("ListColumnSettings", "POS: Name column is always visible per isAlwaysVisible", result: ListColumn.name.isAlwaysVisible == true)
        report("ListColumnSettings", "NEG: non-name columns report isAlwaysVisible == false", result: ListColumn.allCases.filter { $0 != .name }.allSatisfy { $0.isAlwaysVisible == false })
    }

    private static func testListColumnDefaultWidths() {
        let defaults = ListColumnState.defaults()
        let withinBounds = defaults.allSatisfy { state in
            state.column == .name || (state.width >= LayoutTokens.columnMinWidth && state.width <= LayoutTokens.columnMaxWidth)
        }
        report("ListColumnSettings", "POS: default widths for fixed-width columns fall within columnMinWidth...columnMaxWidth", result: withinBounds)

        let widthsMatch = defaults.allSatisfy { $0.width == $0.column.defaultWidth }
        report("ListColumnSettings", "POS: each default state's width matches its column's defaultWidth", result: widthsMatch)

        report("ListColumnSettings", "NEG: name column's defaultWidth (280) is not clamped to columnMinWidth like other small values would be", result: ListColumn.name.defaultWidth == 280 && ListColumn.name.defaultWidth != LayoutTokens.columnMinWidth)
    }

    private static func testListColumnStateCodableRoundTrip() {
        let state = ListColumnState(column: .kind, width: 145, isVisible: true)
        do {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(ListColumnState.self, from: data)
            let matches = decoded.column == state.column && decoded.width == state.width && decoded.isVisible == state.isVisible
            report("ListColumnSettings", "POS: ListColumnState JSON encode/decode round-trip preserves column, width, isVisible", result: matches)
        } catch {
            report("ListColumnSettings", "POS: ListColumnState JSON encode/decode round-trip preserves column, width, isVisible", result: false)
        }

        do {
            let array = ListColumnState.defaults()
            let data = try JSONEncoder().encode(array)
            let decodedArray = try JSONDecoder().decode([ListColumnState].self, from: data)
            report("ListColumnSettings", "POS: full defaults() array survives JSON round-trip with matching count and order", result: decodedArray.map { $0.column } == array.map { $0.column })
        } catch {
            report("ListColumnSettings", "POS: full defaults() array survives JSON round-trip with matching count and order", result: false)
        }

        do {
            let data = "{\"column\":\"Not A Column\",\"width\":50,\"isVisible\":true}".data(using: .utf8)!
            _ = try JSONDecoder().decode(ListColumnState.self, from: data)
            report("ListColumnSettings", "NEG: ListColumnState fails to decode when column raw value is unrecognized", result: false)
        } catch {
            report("ListColumnSettings", "NEG: ListColumnState fails to decode when column raw value is unrecognized", result: true)
        }
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
