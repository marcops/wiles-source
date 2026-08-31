import Foundation
import GitBeacon
import Observation

/// Owns persistence (load/save/CRUD) for auto-organization rules, backed by `UserDefaults`.
/// Notifies `onChange` after every mutation so an owner can react (e.g. restart folder watching)
/// without this store knowing anything about watching.
/// `@Observable` so `AutoOrganizationSheet` can bind straight to `rules` (incl. background
/// `totalMovedCount`/`lastTriggeredAt` bumps) instead of keeping a manually-refreshed copy.
@Observable
@MainActor
final class AutoOrganizationRuleStore {
    private let rulesKey = DefaultsKey.autoOrganizationRules.rawValue

    /// Invoked after every mutation to `rules` (load, direct assignment, add/update/delete).
    var onChange: (() -> Void)?

    /// Set while `load()` seeds `rules` from disk, so its `didSet` doesn't immediately re-encode the
    /// identical data back to `UserDefaults` and fire an extra `onChange` (→ redundant
    /// `restartMonitoring`).
    private var isLoading = false
    /// Set while `bumpStats` mutates only a rule's `lastTriggeredAt`/`totalMovedCount` — that's not a
    /// structural change, so the `didSet` skips the synchronous save + `onChange` and a debounced
    /// save covers it instead (a burst of background moves otherwise rewrote `UserDefaults` and
    /// restarted every watcher once per file).
    private var isBumpingStats = false
    private var statsSaveTask: Task<Void, Never>?
    private static let statsSaveDebounce: Duration = .seconds(2)

    var rules: [AutoOrganizationRule] = [] {
        didSet {
            guard !isLoading, !isBumpingStats else { return }
            saveRules()
            onChange?()
        }
    }

    /// Records a successful auto-move on `id` without the structural-change side effects: updates
    /// the in-memory rule (so the sheet's counter reflects it live) and schedules one debounced
    /// persist for the whole burst.
    func bumpStats(id: UUID, at date: Date) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        isBumpingStats = true
        rules[index].lastTriggeredAt = date
        rules[index].totalMovedCount += 1
        isBumpingStats = false

        statsSaveTask?.cancel()
        statsSaveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.statsSaveDebounce)
            guard let self, !Task.isCancelled else { return }
            saveRules()
        }
    }

    /// Runs the pending debounced stats persist immediately — call from `applicationWillTerminate`
    /// so a burst of auto-moves in the last 2s before quit isn't lost.
    func flushPendingSaves() {
        guard statsSaveTask != nil else { return }
        statsSaveTask?.cancel()
        statsSaveTask = nil
        saveRules()
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
            ErrorReporter.report(error, context: "Decoding auto-organization rules")
        }
    }

    private func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            UserDefaults.standard.set(data, forKey: rulesKey)
        } catch {
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
