import Foundation
import XCTest
@testable import Wiles

/// MM-131: `FavoritesStore.favoriteURLs.didSet` used to call `resolvingSymlinksInPath()` (a
/// per-component `lstat`) synchronously on `@MainActor` — a single `/Volumes/` favorite on a
/// stalled share froze the launch / every window open. The symlink resolution now runs off the
/// main actor and lands in `resolvedFavoritePaths` asynchronously; the synchronous path only does
/// pure string work.
@MainActor
final class FavoritesStoreResolvedPathsTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir.standardizedFileURL
    }

    // MARK: - pure helper

    func testResolvedPathsFollowsSymlink() throws {
        let root = try makeTempDir()
        let real = root.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        let resolved = FavoritesStore.resolvedPaths(for: [link])
        XCTAssertEqual(resolved, [real.path], "the resolved set must contain the symlink's real target, not the link path")
    }

    func testResolvedPathsPassesThroughPlainPaths() throws {
        let root = try makeTempDir()
        let dirA = root.appendingPathComponent("a")
        let dirB = root.appendingPathComponent("b")
        XCTAssertEqual(FavoritesStore.resolvedPaths(for: [dirA, dirB]), [dirA.path, dirB.path])
    }

    // MARK: - store: sync path is pure, resolved set catches up async

    func testDidSetUpdatesStandardizedPathsSynchronouslyAndResolvedAsync() async throws {
        let root = try makeTempDir()
        let real = root.appendingPathComponent("Docs")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("DocsLink")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        let store = FavoritesStore()
        store.favoriteURLs = [link]

        // Synchronous: the plain standardized path is available immediately (no I/O).
        XCTAssertTrue(store.standardizedFavoritePaths.contains(link.standardizedFileURL.path))

        // Asynchronous: the symlink-resolved set catches up shortly after.
        let landed = await pollUntilTrue { store.resolvedFavoritePaths.contains(real.path) }
        XCTAssertTrue(landed, "resolvedFavoritePaths must eventually contain the symlink's real target")
    }

    /// A rapid second assignment must win — the earlier off-main resolution is cancelled/ignored.
    func testLatestAssignmentWins() async throws {
        let root = try makeTempDir()
        let store = FavoritesStore()
        let dirA = root.appendingPathComponent("a")
        let dirB = root.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)

        store.favoriteURLs = [dirA]
        store.favoriteURLs = [dirB]

        let converged = await pollUntilTrue { store.resolvedFavoritePaths == [dirB.path] }
        XCTAssertTrue(converged, "resolvedFavoritePaths must converge to the last assignment, not a stale earlier one")
    }

    private func pollUntilTrue(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 50 {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        return condition()
    }
}
