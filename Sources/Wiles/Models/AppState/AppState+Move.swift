import AppKit
import Foundation
import GitBeacon
import SwiftUI

/// In-app move orchestration: the single `moveItem` entry point plus the sequential
/// collision-resolving batch loop (Replace / Keep Both / Cancel, with "apply to all") shared by
/// the drag-onto-folder, breadcrumb-drop and cut-paste paths. Favorites/view-mode remapping and
/// the collision-restore undo bookkeeping live here alongside the move itself.
public extension AppState {
    /// Single entry point for every in-app move (cut/paste, drag onto a folder row, breadcrumb
    /// drop, sidebar-favorite drop) — moves the item on disk, then keeps favorites in sync. Every
    /// call site should go through this, not call `FileSystemService.moveItem` directly, so a
    /// second in-app move location can never again forget to re-sync favorites via
    /// `remapRelocatedState` after every move.
    @discardableResult
    func moveItem(
        at url: URL,
        toFolder targetFolder: URL,
        onCollision: MoveCollisionPolicy = .failIfExists) async throws -> URL {
        let destURL = try await FileSystemService.moveItem(at: url, toFolder: targetFolder, onCollision: onCollision)
        remapRelocatedState(from: url, to: destURL)
        return destURL
    }

    /// Moves each URL into `targetFolder` sequentially via `moveOneResolvingCollision` (the same
    /// per-item mover the cut/paste loop uses), aggregating failures into one alert. `.cancel` stops
    /// the batch. Used by the drag-onto-folder and breadcrumb-drop paths, which don't record undo.
    @discardableResult
    func moveItemsResolvingCollisions(
        _ urls: [URL],
        toFolder targetFolder: URL,
        windowUIState: WindowUIState) async -> [URL] {
        let (moved, failureCount) = await moveBatchResolvingCollisions(urls, into: targetFolder, windowUIState: windowUIState)
        if failureCount > 0 {
            showPartialFailure(.movePartialFailure, failed: failureCount, total: urls.count)
        }
        return moved
    }

    /// The shared sequential collision-resolving move loop behind both `moveItemsResolvingCollisions`
    /// (drag/breadcrumb drops) and the cut branch of `pasteAllItems`. Prompts once per collision
    /// with an "apply to all" sticky choice; `.cancel` stops the batch. `onMoved(source, dest,
    /// displacedExisting)` fires after each success (the paste path records undo there); `progress`
    /// after each iteration. Returns the moved destinations and the failure count — the caller
    /// shows its own partial-failure message (the l10n key differs per caller).
    func moveBatchResolvingCollisions(
        _ urls: [URL],
        into targetFolder: URL,
        windowUIState: WindowUIState?,
        onMoved: (_ source: URL, _ dest: URL, _ displacedExisting: Bool, _ displacedTrashedURL: URL?) -> Void = { _, _, _, _ in },
        progress: (_ completed: Int) -> Void = { _ in }) async -> (moved: [URL], failureCount: Int) {
        var sticky: MoveCollisionChoice.Action?
        var moved: [URL] = []
        var failureCount = 0
        for (index, url) in urls.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                let (outcome, newSticky) = try await moveOneResolvingCollision(
                    url, into: targetFolder, sticky: sticky,
                    moreFollow: index < urls.count - 1, windowUIState: windowUIState)
                sticky = newSticky
                switch outcome {
                case let .moved(dest, displacedExisting, displacedTrashedURL):
                    moved.append(dest)
                    onMoved(url, dest, displacedExisting, displacedTrashedURL)
                case .skipped:
                    break
                case .cancelled:
                    return (moved, failureCount)
                }
            } catch {
                ErrorReporter.report(error, context: "Moving item into folder")
                failureCount += 1
            }
            progress(index + 1)
        }
        return (moved, failureCount)
    }

    /// Moves one item into `targetFolder`, resolving a name collision via the per-window prompt
    /// (Replace / Keep Both / Cancel, with "apply to all") and keeping favorites/view-mode keys in
    /// sync. Records no undo — the caller does, since only some callers want it. Returns the outcome
    /// and the (possibly updated) sticky choice for the rest of the batch.
    internal func moveOneResolvingCollision(
        _ url: URL,
        into targetFolder: URL,
        sticky: MoveCollisionChoice.Action?,
        moreFollow: Bool,
        windowUIState: WindowUIState?) async throws -> (BatchMoveOutcome, MoveCollisionChoice.Action?) {
        do {
            let dest = try await FileSystemService.moveItem(at: url, toFolder: targetFolder)
            remapRelocatedState(from: url, to: dest)
            return (.moved(to: dest, displacedExisting: false, displacedTrashedURL: nil), sticky)
        } catch WilesError.destinationExists {
            guard let windowUIState else { return (.skipped, sticky) }
            let resolution = await resolveCollision(
                itemName: url.lastPathComponent, moreCollisionsPossible: moreFollow,
                sticky: sticky, windowUIState: windowUIState)
            guard let policy = resolution.action.policy else {
                return (.cancelled, resolution.sticky)
            }
            if policy == .replace {
                let outcome = try await FileSystemService.moveItemReplacing(at: url, toFolder: targetFolder)
                remapRelocatedState(from: url, to: outcome.destination)
                return (.moved(to: outcome.destination, displacedExisting: true, displacedTrashedURL: outcome.displacedTrashedURL), resolution.sticky)
            }
            let dest = try await FileSystemService.moveItem(at: url, toFolder: targetFolder, onCollision: policy)
            remapRelocatedState(from: url, to: dest)
            return (.moved(to: dest, displacedExisting: false, displacedTrashedURL: nil), resolution.sticky)
        }
    }

    /// Resolves one name collision: returns the remembered `sticky` action if the user already chose
    /// "apply to all", otherwise prompts and returns the new sticky (non-nil only if they checked it).
    /// Shared by `moveItemsResolvingCollisions` and the cut/paste loop.
    func resolveCollision(
        itemName: String,
        moreCollisionsPossible: Bool,
        sticky: MoveCollisionChoice.Action?,
        windowUIState: WindowUIState) async -> (action: MoveCollisionChoice.Action, sticky: MoveCollisionChoice.Action?) {
        if let sticky {
            return (sticky, sticky)
        }
        let choice = await windowUIState.promptMoveCollision(itemName: itemName, showApplyToAll: moreCollisionsPossible)
        return (choice.action, choice.applyToAll ? choice.action : nil)
    }
}
