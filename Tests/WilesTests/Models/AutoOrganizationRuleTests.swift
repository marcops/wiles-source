import Foundation
@testable import Wiles

@MainActor
public struct AutoOrganizationRuleTests {
    public static func run() {
        testCodableRoundTrip()
        testDefaultIsEnabled()
        testIdentityIsUniquePerInstance()
        testConditionTypeCases()
    }

    private static func testCodableRoundTrip() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let source = dir.appendingPathComponent("Source")
        let destination = dir.appendingPathComponent("Destination")

        let rule = AutoOrganizationRule(
            id: UUID(),
            sourceURL: source,
            destinationURL: destination,
            conditionType: .extensionEquals,
            conditionValue: "pdf",
            isEnabled: false)

        do {
            let data = try JSONEncoder().encode(rule)
            let decoded = try JSONDecoder().decode(AutoOrganizationRule.self, from: data)
            let matches = decoded.id == rule.id
                && decoded.sourceURL == rule.sourceURL
                && decoded.destinationURL == rule.destinationURL
                && decoded.conditionType == rule.conditionType
                && decoded.conditionValue == rule.conditionValue
                && decoded.isEnabled == rule.isEnabled
            report("Model/AutoOrganizationRule", "POS: JSON encode/decode round-trip preserves all fields exactly", result: matches)
        } catch {
            report("Model/AutoOrganizationRule", "POS: JSON encode/decode round-trip preserves all fields exactly", result: false)
        }
    }

    private static func testDefaultIsEnabled() {
        let rule = AutoOrganizationRule(
            sourceURL: URL(fileURLWithPath: testTemporaryDirectory()),
            destinationURL: URL(fileURLWithPath: testTemporaryDirectory()),
            conditionType: .nameContains,
            conditionValue: "invoice")
        report("Model/AutoOrganizationRule", "POS: default initializer sets isEnabled to true when omitted", result: rule.isEnabled)
    }

    private static func testIdentityIsUniquePerInstance() {
        let source = URL(fileURLWithPath: testTemporaryDirectory())
        let destination = URL(fileURLWithPath: testTemporaryDirectory())
        let ruleA = AutoOrganizationRule(sourceURL: source, destinationURL: destination, conditionType: .namePrefix, conditionValue: "IMG")
        let ruleB = AutoOrganizationRule(sourceURL: source, destinationURL: destination, conditionType: .namePrefix, conditionValue: "IMG")
        report(
            "Model/AutoOrganizationRule",
            "NEG: two independently-constructed rules with identical fields get distinct auto-generated ids",
            result: ruleA.id != ruleB.id)

        let fixedID = UUID()
        let ruleC = AutoOrganizationRule(id: fixedID, sourceURL: source, destinationURL: destination, conditionType: .namePrefix, conditionValue: "IMG")
        let ruleD = AutoOrganizationRule(id: fixedID, sourceURL: source, destinationURL: destination, conditionType: .namePrefix, conditionValue: "IMG")
        report(
            "Model/AutoOrganizationRule",
            "POS: rules constructed with the same explicit id compare equal (Hashable/Equatable via memberwise synthesis)",
            result: ruleC == ruleD && ruleC.id == ruleD.id)
    }

    /// RuleConditionType is the tightly-coupled enum backing `AutoOrganizationRule.conditionType` -
    /// covered here alongside the rule itself rather than a separate dedicated file, since it's a
    /// single-property namespace with no independent behavior of its own.
    private static func testConditionTypeCases() {
        let allCases = RuleConditionType.allCases
        let uniqueIDs = Set(allCases.map(\.id))
        report(
            "Model/AutoOrganizationRule",
            "POS: RuleConditionType.allCases has 3 cases with unique ids matching their raw values",
            result: allCases.count == 3 && uniqueIDs.count == 3 && allCases.allSatisfy { $0.id == $0.rawValue })

        do {
            let data = try JSONEncoder().encode(RuleConditionType.extensionEquals)
            let decoded = try JSONDecoder().decode(RuleConditionType.self, from: data)
            report("Model/AutoOrganizationRule", "POS: RuleConditionType Codable round-trip preserves case", result: decoded == .extensionEquals)
        } catch {
            report("Model/AutoOrganizationRule", "POS: RuleConditionType Codable round-trip preserves case", result: false)
        }

        do {
            let data = Data("\"Not A Real Condition\"".utf8)
            _ = try JSONDecoder().decode(RuleConditionType.self, from: data)
            report("Model/AutoOrganizationRule", "NEG: RuleConditionType fails to decode an unrecognized raw value", result: false)
        } catch {
            report("Model/AutoOrganizationRule", "NEG: RuleConditionType fails to decode an unrecognized raw value", result: true)
        }
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
