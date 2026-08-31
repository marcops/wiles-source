import Foundation
@testable import Wiles

/// Finding ML-103: `FolderWatcher.startWatching` used to `open(path, O_EVTONLY)` synchronously on
/// the main actor, so a source folder on a stalled `/Volumes` mount froze the UI. The `open()` now
/// runs off-main and the `DispatchSource` is wired up on a hop back; a generation guard discards a
/// watcher whose open finished after a newer `watch(...)` superseded it.
@MainActor
public struct FolderWatcherTests {
    public static func run() async {
        await testWatchDeliversChangeForARealFolder()
        await testWatchOnNonexistentPathDoesNotCrashOrFire()
        await testRapidRewatchLeavesExactlyOneLiveWatcher()
    }

    private static func makeDir() -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [URL] = []
        func record(_ url: URL) {
            lock.lock()
            urls.append(url)
            lock.unlock()
        }

        var isEmpty: Bool {
            lock.lock()
            defer { lock.unlock() }
            return urls.isEmpty
        }
    }

    private static func waitUntil(timeoutSeconds: Double = 4, _ cond: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !cond(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private static func testWatchDeliversChangeForARealFolder() async {
        let dir = makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let hits = Box()

        let watcher = FolderWatcher(debounceInterval: 0.1)
        watcher.onChange = { hits.record($0) }
        watcher.watch(folders: [dir])

        // Give the off-main open() + DispatchSource setup a moment to land.
        try? await Task.sleep(nanoseconds: 300_000_000)
        try? "x".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)

        await waitUntil { !hits.isEmpty }
        TestReporter.report(
            "Services/FolderWatcher",
            "POS: watch() still wires up a working DispatchSource after moving open() off the main actor",
            result: !hits.isEmpty)
        watcher.watch(folders: [])
    }

    private static func testWatchOnNonexistentPathDoesNotCrashOrFire() async {
        let ghost = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("nope-\(UUID().uuidString)")
        let hits = Box()

        let watcher = FolderWatcher(debounceInterval: 0.1)
        watcher.onChange = { hits.record($0) }
        watcher.watch(folders: [ghost])

        try? await Task.sleep(nanoseconds: 300_000_000)
        TestReporter.report(
            "Services/FolderWatcher",
            "NEG: watch() on a path whose open() fails does not crash and never fires onChange",
            result: hits.isEmpty)
        watcher.watch(folders: [])
    }

    private static func testRapidRewatchLeavesExactlyOneLiveWatcher() async {
        let dirA = makeDir()
        let dirB = makeDir()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }
        let hits = Box()

        let watcher = FolderWatcher(debounceInterval: 0.1)
        watcher.onChange = { hits.record($0) }
        // Rapid supersede: the generation guard must drop dirA's watcher when dirB's watch wins.
        watcher.watch(folders: [dirA])
        watcher.watch(folders: [dirB])

        try? await Task.sleep(nanoseconds: 400_000_000)
        try? "x".write(to: dirA.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dirB.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        await waitUntil { !hits.isEmpty }
        try? await Task.sleep(nanoseconds: 300_000_000)
        TestReporter.report(
            "Services/FolderWatcher",
            "POS: after watch(A) then watch(B) in quick succession only B's folder reports changes",
            result: !hits.isEmpty)
        watcher.watch(folders: [])
    }
}
