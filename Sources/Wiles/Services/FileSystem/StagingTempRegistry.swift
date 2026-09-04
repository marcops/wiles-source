import Foundation

/// Process-wide set of `.wiles-*-<UUID>` staging-temp UUIDs in use by a live filesystem operation.
/// The crash-orphan sweep consults it so it can't delete a temp whose (slow, cross-volume) move
/// outruns the age threshold.
enum StagingTempRegistry {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var liveUUIDs: Set<String> = []

    /// Call immediately before creating the `<prefix><uuid>` staging file; pair with `unregister`
    /// (a `defer`) once the temp has been moved to its final home or to the Trash.
    static func register(_ uuid: String) {
        lock.withLock { _ = liveUUIDs.insert(uuid) }
    }

    static func unregister(_ uuid: String) {
        lock.withLock { _ = liveUUIDs.remove(uuid) }
    }

    static func isLive(_ uuid: String) -> Bool {
        lock.withLock { liveUUIDs.contains(uuid) }
    }

    /// `true` when `fileName` is `<prefix><uuid>` for one of `prefixes` and that `uuid` is currently
    /// registered. `false` for a name with no matching prefix or an unregistered (orphan) uuid.
    static func isLiveTempFileName(_ fileName: String, prefixes: [String]) -> Bool {
        for prefix in prefixes where fileName.hasPrefix(prefix) {
            return isLive(String(fileName.dropFirst(prefix.count)))
        }
        return false
    }
}
