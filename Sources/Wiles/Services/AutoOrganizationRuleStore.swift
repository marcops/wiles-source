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
    /// Debounced stats persist, auto-registered for the terminate-time flush.
    private let statsWrite = DebouncedDefaultsWrite(interval: 2)

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

        statsWrite.schedule { [weak self] in self?.saveRules() }
    }

    /// Runs the pending debounced stats persist immediately. Called from `applicationWillTerminate`
    /// via `DebouncedWriteRegistry.flushAll()` (and `AutoOrganizationService.flushPendingSaves()`)
    /// so a burst of auto-moves in the last 2s before quit isn't lost.
    func flushPendingSaves() {
        statsWrite.flush()
    }

    /// Loads persisted rules from `UserDefaults`. A no-op if none are stored yet.
    ///
    /// Decoded element-by-element (`FailableDecodable`): a single corrupt or forward-incompatible
    /// record (e.g. a `RuleConditionType` from a newer build, then a downgrade) drops just that
    /// entry instead of wiping every rule. Any survivors are re-persisted so the bad record can't
    /// re-fail on every launch, and the drop is reported via `ErrorReporter` (no window at launch
    /// to surface it in). If the top-level JSON itself is unreadable, `rules` is left untouched.
    ///
    func load() {
        guard let data = UserDefaults.standard.data(forKey: rulesKey) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let decoded = try JSONDecoder().decode([FailableDecodable<AutoOrganizationRule>].self, from: data)
            let valid = decoded.compactMap(\.value)
            rules = valid
            let dropped = decoded.count - valid.count
            if dropped > 0 {
                ErrorReporter.report(
                    RuleDecodeError.partialFailure(dropped: dropped, total: decoded.count),
                    context: "Auto-organization: \(dropped) of \(decoded.count) saved rules could not be decoded and were skipped")
                saveRules()
            }
        } catch {
            ErrorReporter.report(error, context: "Decoding auto-organization rules")
        }
    }

    enum RuleDecodeError: Error {
        case partialFailure(dropped: Int, total: Int)
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
