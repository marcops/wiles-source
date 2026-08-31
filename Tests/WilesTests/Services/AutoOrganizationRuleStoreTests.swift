import Foundation
@testable import Wiles

/// Coverage for `AutoOrganizationRuleStore` itself (persistence/CRUD), distinct from
/// `AutoOrganizationTests.swift` (which exercises the full `AutoOrganizationService` pipeline via
/// its own private store instance) and `AutoOrganizationRuleTests.swift` (the `AutoOrganizationRule`
/// model). Isolates the real `UserDefaults.standard` key it persists to, restoring the original
/// value in a guaranteed `defer` per DEV_RULES.md/WILES_RULES.md test-isolation rules.
@MainActor
public struct AutoOrganizationRuleStoreTests {
    private static let rulesKey = DefaultsKey.autoOrganizationRules.rawValue

    public static func run() {
        let originalValue = UserDefaults.standard.data(forKey: rulesKey)
        defer {
            if let originalValue {
                UserDefaults.standard.set(originalValue, forKey: rulesKey)
            } else {
                UserDefaults.standard.removeObject(forKey: rulesKey)
            }
        }

        testLoadWithNoStoredDataIsNoOp()
        testLoadDecodesPreviouslySavedRules()
        testLoadWithCorruptDataLeavesRulesUnchanged()
        testLoadSkipsOneBadRecordAndKeepsTheValidOnes()
        testAddUpdateDeleteRuleMutateAndPersist()
        testUpdateRuleWithUnknownIdIsNoOp()
        testOnChangeFiresOnEveryMutation()
        testLoadDoesNotReSaveOrFireOnChange()
        testBumpStatsUpdatesInMemoryWithoutStructuralSideEffects()
    }

    /// A successful background auto-move bumps a rule's stats. That's not a structural change, so it
    /// must update the in-memory rule (the sheet's counter reads it live) without firing `onChange`
    /// (→ redundant watcher restart) or writing `UserDefaults` synchronously per move.
    private static func testBumpStatsUpdatesInMemoryWithoutStructuralSideEffects() {
        UserDefaults.standard.removeObject(forKey: rulesKey)
        let rule = makeRule()
        let store = AutoOrganizationRuleStore()
        var onChangeCalls = 0
        store.onChange = { onChangeCalls += 1 }
        store.addRule(rule)
        onChangeCalls = 0
        UserDefaults.standard.removeObject(forKey: rulesKey)

        store.bumpStats(id: rule.id, at: Date(timeIntervalSince1970: 1000))
        store.bumpStats(id: rule.id, at: Date(timeIntervalSince1970: 2000))

        report(
            "Services/AutoOrganizationRuleStore",
            "POS: bumpStats increments totalMovedCount and sets lastTriggeredAt in memory",
            result: store.rules.first?.totalMovedCount == 2 && store.rules.first?.lastTriggeredAt == Date(timeIntervalSince1970: 2000))
        report(
            "Services/AutoOrganizationRuleStore",
            "NEG: bumpStats does not fire onChange (no watcher restart per move)",
            result: onChangeCalls == 0)
        report(
            "Services/AutoOrganizationRuleStore",
            "NEG: bumpStats does not write UserDefaults synchronously (persist is debounced)",
            result: UserDefaults.standard.data(forKey: rulesKey) == nil)
    }

    /// P3: `load()` seeds `rules` from disk; its `didSet` must not immediately re-encode the same
    /// data back or fire `onChange` (which would trigger a redundant `restartMonitoring`).
    private static func testLoadDoesNotReSaveOrFireOnChange() {
        let rule = makeRule()
        UserDefaults.standard.set(try? JSONEncoder().encode([rule]), forKey: rulesKey)
        let before = UserDefaults.standard.data(forKey: rulesKey)

        let store = AutoOrganizationRuleStore()
        var onChangeCalls = 0
        store.onChange = { onChangeCalls += 1 }
        store.load()

        report(
            "Services/AutoOrganizationRuleStore",
            "NEG: load() does not fire onChange",
            result: onChangeCalls == 0)
        report(
            "Services/AutoOrganizationRuleStore",
            "POS: load() leaves the persisted bytes untouched (no round-trip re-save)",
            result: UserDefaults.standard.data(forKey: rulesKey) == before && store.rules.map(\.id) == [rule.id])
    }

    private static func makeRule(name: String = "pdf") -> AutoOrganizationRule {
        let base = URL(fileURLWithPath: testTemporaryDirectory())
        return AutoOrganizationRule(
            sourceURL: base.appendingPathComponent("Source_\(UUID().uuidString)"),
            destinationURL: base.appendingPathComponent("Dest_\(UUID().uuidString)"),
            conditionType: .extensionEquals,
            conditionValue: name,
            isEnabled: true)
    }

    private static func testLoadWithNoStoredDataIsNoOp() {
        UserDefaults.standard.removeObject(forKey: rulesKey)
        let store = AutoOrganizationRuleStore()
        store.load()
        report("Services/AutoOrganizationRuleStore", "NEG: load() with nothing stored leaves rules empty", result: store.rules.isEmpty)
    }

    private static func testLoadDecodesPreviouslySavedRules() {
        let rule = makeRule()
        let data = try? JSONEncoder().encode([rule])
        UserDefaults.standard.set(data, forKey: rulesKey)

        let store = AutoOrganizationRuleStore()
        store.load()
        report(
            "Services/AutoOrganizationRuleStore",
            "POS: load() decodes a previously persisted rule list from UserDefaults",
            result: store.rules.map(\.id) == [rule.id])
    }

    private static func testLoadWithCorruptDataLeavesRulesUnchanged() {
        UserDefaults.standard.set(Data("not valid json".utf8), forKey: rulesKey)

        let store = AutoOrganizationRuleStore()
        store.load()
        report(
            "Services/AutoOrganizationRuleStore",
            "NEG: load() with corrupt stored data logs/reports the decode error and leaves rules untouched (empty)",
            result: store.rules.isEmpty)
    }

    /// ML-104: a single forward-incompatible / corrupt record (here an unknown `conditionType`,
    /// e.g. saved by a newer build then opened after a downgrade) must not wipe every rule. The
    /// valid entries survive, and are re-persisted so the bad one can't re-fail next launch.
    private static func testLoadSkipsOneBadRecordAndKeepsTheValidOnes() {
        let valid = makeRule()
        guard let validData = try? JSONEncoder().encode(valid),
              let validObj = (try? JSONSerialization.jsonObject(with: validData)) as? [String: Any] else {
            report("Services/AutoOrganizationRuleStore", "SETUP: could not build fixture JSON", result: false)
            return
        }
        var badObj = validObj
        badObj["id"] = UUID().uuidString
        badObj["conditionType"] = "conditionFromANewerBuild"
        guard let arrayData = try? JSONSerialization.data(withJSONObject: [validObj, badObj]) else {
            report("Services/AutoOrganizationRuleStore", "SETUP: could not serialize fixture array", result: false)
            return
        }
        UserDefaults.standard.set(arrayData, forKey: rulesKey)

        let store = AutoOrganizationRuleStore()
        store.load()
        report(
            "Services/AutoOrganizationRuleStore",
            "POS: load() skips the undecodable record and keeps the valid rule (ML-104: was all-or-nothing)",
            result: store.rules.map(\.id) == [valid.id])

        // The survivors were re-saved, so a fresh load sees a clean list with nothing left to drop.
        let store2 = AutoOrganizationRuleStore()
        store2.load()
        report(
            "Services/AutoOrganizationRuleStore",
            "POS: load() re-persists the surviving rules so the bad record doesn't re-fail every launch",
            result: store2.rules.map(\.id) == [valid.id])
    }

    private static func testAddUpdateDeleteRuleMutateAndPersist() {
        UserDefaults.standard.removeObject(forKey: rulesKey)
        let store = AutoOrganizationRuleStore()
        let rule = makeRule()

        store.addRule(rule)
        report("Services/AutoOrganizationRuleStore", "POS: addRule() appends the new rule", result: store.rules.map(\.id) == [rule.id])

        var updated = rule
        updated.conditionValue = "docx"
        store.updateRule(updated)
        report(
            "Services/AutoOrganizationRuleStore",
            "POS: updateRule() replaces the rule with matching id",
            result: store.rules.first?.conditionValue == "docx")

        // The property's didSet saves synchronously to UserDefaults.standard — a fresh store loading
        // the same key should observe the just-saved, updated rule.
        let reloadStore = AutoOrganizationRuleStore()
        reloadStore.load()
        report(
            "Services/AutoOrganizationRuleStore",
            "POS: mutations are persisted synchronously — a freshly loaded store observes the update",
            result: reloadStore.rules.first?.conditionValue == "docx")

        store.deleteRule(id: rule.id)
        report(
            "Services/AutoOrganizationRuleStore",
            "POS: deleteRule() removes the rule with matching id",
            result: store.rules.isEmpty)
    }

    private static func testUpdateRuleWithUnknownIdIsNoOp() {
        UserDefaults.standard.removeObject(forKey: rulesKey)
        let store = AutoOrganizationRuleStore()
        let rule = makeRule()
        store.addRule(rule)

        var unknown = makeRule()
        unknown.conditionValue = "should-not-apply"
        store.updateRule(unknown)

        report(
            "Services/AutoOrganizationRuleStore",
            "NEG: updateRule() with an id not present in rules is a no-op",
            result: store.rules.count == 1 && store.rules.first?.id == rule.id)
    }

    private static func testOnChangeFiresOnEveryMutation() {
        UserDefaults.standard.removeObject(forKey: rulesKey)
        let store = AutoOrganizationRuleStore()
        var callCount = 0
        store.onChange = { callCount += 1 }

        store.addRule(makeRule())
        store.rules = []

        report("Services/AutoOrganizationRuleStore", "POS: onChange fires once per rules mutation", result: callCount == 2)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
