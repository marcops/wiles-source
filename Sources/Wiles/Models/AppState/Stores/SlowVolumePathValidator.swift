import Foundation

/// Shared `/Volumes/` existence-check helpers for stores that accept a possibly-stale saved path
/// optimistically at init (to avoid stalling window construction on a sleeping/unreachable network
/// mount) and verify it afterward off `@MainActor`. Used by `NavigationStore` and `PreferencesStore`,
/// which previously each hand-rolled an identical private copy of this pair.
enum SlowVolumePathValidator {
    static func isLikelySlowVolume(_ path: String) -> Bool {
        path.hasPrefix("/Volumes/")
    }

    /// Skips the synchronous `fileExists` check for a `/Volumes/` path — it's accepted as-is here
    /// and expected to be verified later off-`@MainActor` by the caller.
    static func existsOptimistically(atPath path: String) -> Bool {
        isLikelySlowVolume(path) || FileManager.default.fileExists(atPath: path)
    }

    /// The `/Volumes/<name>` mount root for a `/Volumes/...` path (or the path itself when it already
    /// *is* `/Volumes/<name>`). `nil` for any non-`/Volumes/` path. Lets a validator tell "the folder
    /// was deleted" (volume mounted, target gone → safe to prune a saved entry) from "the volume is
    /// just offline right now" (mount root gone → keep the entry, it's transient — MH-118).
    static func volumeMountRoot(forPath path: String) -> String? {
        guard isLikelySlowVolume(path) else { return nil }
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count >= 2 else { return nil }
        return "/Volumes/\(components[1])"
    }

    /// Whether a validated `/Volumes/` `path` that came back as non-existent should be **kept**
    /// anyway: keep it when its whole `/Volumes/<name>` mount root is also gone (the volume is just
    /// offline), prune only when the volume is mounted but the target folder isn't (deleted).
    /// Non-`/Volumes/` paths are never kept by this rule. `exists` maps every path that was checked.
    static func shouldKeepUnreachableSlowVolumePath(_ path: String, exists: [String: Bool]) -> Bool {
        guard let root = volumeMountRoot(forPath: path) else { return false }
        return !(exists[root] ?? false)
    }
}
