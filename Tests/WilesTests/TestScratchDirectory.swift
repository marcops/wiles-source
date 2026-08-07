import Foundation

/// Drop-in replacement for `NSTemporaryDirectory()` in tests only - routes to a RAM-backed volume
/// (see `scripts/setup_test_ramdisk.sh`) when it's mounted, so the hundreds of real file
/// creates/writes/hashes this suite performs never touch the real disk. Falls back to the normal
/// system temp directory when the RAM disk isn't mounted (e.g. running a single test outside the
/// full suite runner, or an environment where the setup script hasn't been run).
///
/// Deliberately mounted OUTSIDE /Volumes/ (at /tmp/WilesTestsRAMDisk, not
/// /Volumes/WilesTestsRAMDisk): AppState.navigateTo() treats any /Volumes/-prefixed path as a
/// possibly-slow external/network mount and dispatches navigation through Task.detached instead
/// of completing synchronously (see AppState+Navigation.swift) - correct production behavior, but
/// it broke every test that assumed navigateTo() on a fast local temp path finishes synchronously.
public func testTemporaryDirectory() -> String {
    let ramDiskPath = "/tmp/WilesTestsRAMDisk"
    var isDir: ObjCBool = false
    if FileManager.default.fileExists(atPath: ramDiskPath, isDirectory: &isDir), isDir.boolValue {
        return ramDiskPath + "/"
    }
    return NSTemporaryDirectory()
}
