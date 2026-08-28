import Foundation
@testable import Wiles

/// R1 guard-rail: every `DefaultsKey` that `PreferencesStore` owns must be referenced in BOTH a
/// persistence write (`didSet` / `save…`) AND a restore path (`load…`), so a new preference can't
/// ship saving-but-not-restoring (silently non-persistent — forbidden by WILES_RULES.md's
/// "Complete State Persistence"). A regex can't prove the pairing; this scans the two source files
/// and asserts each key name appears at least twice.
@MainActor
public struct PreferencesPersistenceRoundTripTests {
    private static let category = "PreferencesStorePersistenceRoundTrip"

    /// `DefaultsKey` cases NOT owned by `PreferencesStore` — persisted by other stores/services, so
    /// they legitimately never appear in these two files. Kept explicit so a genuinely-missing
    /// pairing can't hide behind a silent skip.
    private static let keysNotOwnedByPreferencesStore: Set<String> = [
        "autoOrganizationRules", // AutoOrganizationRuleStore
        "hasShownFullDiskAccessPrompt", // PermissionService
        "lastOpenedFolder", // NavigationStore
        "recentConnectServers", // ConnectToServerStore
        "recentOpenedURLs", // NavigationStore
        "smartFolders" // SmartFolderService (PreferencesStore only exposes CRUD)
    ]

    /// Keys with a `didSet` write but deliberately no restore path. Empty — the one real gap this
    /// test surfaced (`navigationMode`, which reset Shortcut Mode to `.gnome` every launch) is now
    /// paired via `loadEnum(.navigationMode, …)` in `loadViewPreferences`.
    private static let knownMissingRestore: Set<String> = []

    public static func run() {
        guard let sources = loadSources() else { return }
        let caseNames = defaultsKeyCaseNames(in: sources.defaultsKey)
        TestReporter.report(category, "POS: parsed DefaultsKey cases from source (found \(caseNames.count))", result: caseNames.count >= 40)
        checkPairings(caseNames: caseNames, combined: sources.combinedStore)
    }

    private struct Sources {
        let defaultsKey: String
        let combinedStore: String
    }

    private static func loadSources() -> Sources? {
        guard let repoRoot = repoRoot() else {
            TestReporter.report(category, "NEG: could not locate repo root from #filePath", result: false)
            return nil
        }
        let defaultsKeySource = repoRoot.appendingPathComponent("Sources/Wiles/Constants/DefaultsKey.swift")
        let storeSources = [
            repoRoot.appendingPathComponent("Sources/Wiles/Models/AppState/Stores/PreferencesStore.swift"),
            repoRoot.appendingPathComponent("Sources/Wiles/Models/AppState/Stores/PreferencesStore+SmartFolders.swift")
        ]
        guard let defaultsKeyText = try? String(contentsOf: defaultsKeySource, encoding: .utf8) else {
            TestReporter.report(category, "NEG: could not read DefaultsKey.swift", result: false)
            return nil
        }
        let storeTexts = storeSources.compactMap { try? String(contentsOf: $0, encoding: .utf8) }
        guard storeTexts.count == storeSources.count else {
            TestReporter.report(category, "NEG: could not read both PreferencesStore source files", result: false)
            return nil
        }
        return Sources(defaultsKey: defaultsKeyText, combinedStore: storeTexts.joined(separator: "\n"))
    }

    private static func checkPairings(caseNames: [String], combined: String) {
        let skip = keysNotOwnedByPreferencesStore.union(knownMissingRestore)
        for name in caseNames.sorted() where !skip.contains(name) {
            let count = referenceCount(of: name, in: combined)
            TestReporter.report(
                category,
                "POS: DefaultsKey.\(name) is referenced >=2x (write + restore) in PreferencesStore sources (found \(count))",
                result: count >= 2)
        }
        // Document the known gap so it can't silently regress into "expected".
        for name in knownMissingRestore {
            let count = referenceCount(of: name, in: combined)
            TestReporter.report(
                category,
                "INFO: DefaultsKey.\(name) is a KNOWN missing-restore gap (write-only, found \(count) refs) — see fix report",
                result: caseNames.contains(name))
        }
        // The allow-list itself must only name real cases, so it can't rot into a way to silence a real key.
        for name in keysNotOwnedByPreferencesStore {
            TestReporter.report(category, "NEG: allow-list entry \"\(name)\" is a real DefaultsKey case", result: caseNames.contains(name))
        }
    }

    /// `case foo = "wiles_foo"` / `case foo` → `foo`.
    private static func defaultsKeyCaseNames(in source: String) -> [String] {
        var names: [String] = []
        let pattern = #"^\s*case\s+([a-zA-Z_][a-zA-Z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return names }
        regex.enumerateMatches(in: source, range: NSRange(source.startIndex..., in: source)) { match, _, _ in
            guard let match, let range = Range(match.range(at: 1), in: source) else { return }
            names.append(String(source[range]))
        }
        return names
    }

    /// Occurrences of `.name` / `\.name` as a whole token (so `.viewMode` doesn't match `.viewModeForFolder`).
    private static func referenceCount(of name: String, in source: String) -> Int {
        let pattern = "\\." + NSRegularExpression.escapedPattern(for: name) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: source, range: NSRange(source.startIndex..., in: source))
    }

    private static func repoRoot() -> URL? {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0 ..< 12 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
            url = url.deletingLastPathComponent()
        }
        return nil
    }
}
