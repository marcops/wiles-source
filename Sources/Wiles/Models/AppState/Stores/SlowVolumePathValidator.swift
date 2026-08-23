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
}
