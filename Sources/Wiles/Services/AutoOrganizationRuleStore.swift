import Foundation
import GitBeacon
import Observation
import os

/// Owns persistence (load/save/CRUD) for auto-organization rules, backed by `UserDefaults`.
/// Notifies `onChange` after every mutation so an owner can react (e.g. restart folder watching)
/// without this store knowing anything about watching.
/// `@Observable` so `AutoOrganizationSheet` can bind straight to `rules` (incl. background
/// `totalMovedCount`/`lastTriggeredAt` bumps) instead of keeping a manually-refreshed copy.
@Observable
@MainActor
final class AutoOrganizationRuleStore {
    private let rulesKey = DefaultsKey.autoOrganizationRules.rawValue
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Wiles", category: "AutoOrganizationRuleStore")

    /// Invoked after every mutation to `rules` (load, direct assignment, add/update/delete).
    var onChange: (() -> Void)?

    /// Set while `load()` seeds `rules` from disk, so its `didSet` doesn't immediately re-encode the
    /// identical data back to `UserDefaults` and fire an extra `onChange` (→ redundant
    /// `restartMonitoring`). Mirrors `NavigationStore`'s `isInitializing` guard.
    private var isLoading = false

    var rules: [AutoOrganizationRule] = [] {
        didSet {
            guard !isLoading else { return }
            saveRules()
            onChange?()
        }
    }

    /// Loads persisted rules from `UserDefaults`. A no-op if none are stored yet; logs and reports
    /// (without mutating `rules`) if the stored data fails to decode.
    func load() {
        guard let data = UserDefaults.standard.data(forKey: rulesKey) else { return }
        do {
            isLoading = true
            defer { isLoading = false }
            rules = try JSONDecoder().decode([AutoOrganizationRule].self, from: data)
        } catch {
            Self.logger.error("Failed to decode auto-organization rules from UserDefaults: \(error.localizedDescription, privacy: .public)")
            ErrorReporter.report(error, context: "Decoding auto-organization rules")
        }
    }

    private func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            UserDefaults.standard.set(data, forKey: rulesKey)
        } catch {
            Self.logger.error("Failed to encode auto-organization rules for UserDefaults: \(error.localizedDescription, privacy: .public)")
            ErrorReporter.report(error, context: "Encoding auto-organization rules")
        }
    }

    func addRule(_ rule: AutoOrganizationRule) {
        rules.append(rule)
    }

    func updateRule(_ rule: AutoOrganizationRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        }
    }

    func deleteRule(id: UUID) {
        rules.removeAll(where: { $0.id == id })
    }
}
