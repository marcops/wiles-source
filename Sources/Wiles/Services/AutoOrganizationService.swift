import Foundation
import GitBeacon

/// Thin coordinator: owns one `AutoOrganizationRuleStore` (rule persistence) and one
/// `FolderWatcher` (DispatchSource lifecycle + debounce), and wires match/dispatch logic between
/// them — matching a watched folder's files against the current rules and moving what qualifies.
@MainActor
public final class AutoOrganizationService {
    public static let shared = AutoOrganizationService()

    private static let scanDebounceInterval: TimeInterval = 0.5

    private let ruleStore = AutoOrganizationRuleStore()
    private let watcher = FolderWatcher(debounceInterval: AutoOrganizationService.scanDebounceInterval)
    /// A matched file is only moved once BOTH its size and modification date stay unchanged across
    /// this window. FileHandle/POSIX lock checks don't work for this: most writers (browsers, curl,
    /// Finder copies) never take an advisory lock, so a locked-file check would never detect an
    /// in-progress download. 2s (not a few hundred ms) so a writer that stalls or writes in spaced
    /// bursts — or whose size momentarily plateaus — isn't mistaken for "done" and moved mid-write.
    private let fileStabilityWindow: Duration = .seconds(2)
    /// Extra consecutive stable windows required before a **cross-volume** auto-move (finding
    /// LL-063). A same-volume move is an atomic rename and can't truncate a file mid-write; a
    /// cross-volume move is copy-then-delete, so a download that stalls for one 2s window and
    /// resumes right after would be copied half-written and the source deleted. Three back-to-back
    /// unchanged windows makes that far less likely.
    private nonisolated static let crossVolumeExtraStableWindows = 3

    public var rules: [AutoOrganizationRule] {
        get { ruleStore.rules }
        set { ruleStore.rules = newValue }
    }

    private init() {
        watcher.onChange = { [weak self] folder in self?.processFolder(folder) }
        ruleStore.onChange = { [weak self] in self?.restartMonitoring() }
        ruleStore.load()
    }

    public func startMonitoring() {
        restartMonitoring()
    }

    public func addRule(_ rule: AutoOrganizationRule) {
        ruleStore.addRule(rule)
    }

    public func updateRule(_ rule: AutoOrganizationRule) {
        ruleStore.updateRule(rule)
    }

    public func deleteRule(id: UUID) {
        ruleStore.deleteRule(id: id)
    }

    /// Flushes the rule store's pending debounced stats write — call from `applicationWillTerminate`.
    public func flushPendingSaves() {
        ruleStore.flushPendingSaves()
    }

    /// Bumps a rule's "last fired" stats after a background move actually succeeds, so the user
    /// has a way to tell whether a rule has ever done anything. Routed through `bumpStats` so a
    /// burst of moves doesn't rewrite `UserDefaults` (and restart the watchers) once per file.
    private func recordSuccessfulMove(ruleID: UUID) {
        ruleStore.bumpStats(id: ruleID, at: Date())
    }

    /// The folder set the `watcher` currently has open `DispatchSource` fds for — lets
    /// `restartMonitoring` skip the teardown/recreate churn when nothing structural changed
    /// (e.g. a rule's stats bumped, but its source folder didn't).
    private var watchedFolders: Set<URL> = []

    private func restartMonitoring() {
        let activeRules = rules.filter(\.isEnabled)
        let uniqueSourceFolders = Set(activeRules.map(\.sourceURL.standardizedFileURL))
        guard uniqueSourceFolders != watchedFolders else { return }
        watchedFolders = uniqueSourceFolders
        watcher.watch(folders: uniqueSourceFolders)
    }

    /// Forwards to the watcher's debounced-callback path — also invoked directly by tests to
    /// simulate a filesystem event without opening a real `DispatchSource`.
    func scheduleProcessFolder(_ folder: URL) {
        watcher.scheduleCallback(for: folder)
    }

    public func processFolder(_ folder: URL) {
        let hasActiveRule = rules.contains { $0.isEnabled && $0.sourceURL.standardizedFileURL == folder.standardizedFileURL }
        guard hasActiveRule else { return }

        // `folder` is a user-configured source path and can point anywhere, including under
        // /Volumes (an SMB/FTP/SFTP share or external drive). contentsOfDirectory(at:) is a
        // synchronous disk call that can block for a long time if that mount has stalled, freezing
        // the whole UI — the same hazard AppState+Navigation's navigateTo guards against for
        // /Volumes/ paths. Detach the initial scan off the main actor; the per-file rule matching
        // and move dispatch below then hop back to the main actor, unchanged.
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: resourceKeys, options: [.skipsSubdirectoryDescendants]) else {
                return
            }
            // Snapshot the rules on the main actor (they may have changed while the scan ran), then
            // do all per-file `resourceValues`/matching off it — the source is typically ~/Downloads
            // with thousands of files, and one stat per file on @MainActor freezes the UI.
            let activeRules = await activeRules(for: folder)
            guard !activeRules.isEmpty else { return }
            let pending = Self.matchMoves(files: files, resourceKeys: resourceKeys, activeRules: activeRules)
            guard !pending.isEmpty else { return }
            await dispatchMoves(pending)
        }
    }

    /// One matched file queued for a background move: `(file, destination, ruleID)`.
    private struct PendingMove: Sendable {
        let file: URL
        let destinationURL: URL
        let ruleID: UUID
    }

    private struct AmbiguousRuleMatch: Error { }

    private func activeRules(for folder: URL) -> [AutoOrganizationRule] {
        rules.filter { $0.isEnabled && $0.sourceURL.standardizedFileURL == folder.standardizedFileURL }
    }

    private nonisolated static func matchMoves(files: [URL], resourceKeys: [URLResourceKey], activeRules: [AutoOrganizationRule]) -> [PendingMove] {
        // A self-referential rule (source resolves to dest, incl. via symlink) would throw
        // `itemAlreadyInDestination` for every matched file on every scan — drop it here so it
        // produces no moves instead of spamming ErrorReporter with no user-visible signal.
        let activeRules = activeRules.filter { !$0.isSelfReferential }
        var pending: [PendingMove] = []
        for file in files {
            // Ignore hidden files and directories
            if file.lastPathComponent.hasPrefix(".") {
                continue
            }
            let resourceValues = try? file.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues?.isDirectory ?? false {
                continue
            }
            let matched = activeRules.filter { matches(file: file, rule: $0) }
            guard let rule = matched.first else { continue }
            if matched.count > 1 {
                reportAmbiguousMatch(file: file, competing: matched)
            }
            pending.append(PendingMove(file: file, destinationURL: rule.destinationURL, ruleID: rule.id))
        }
        return pending
    }

    /// Makes the silent first-match win observable when several enabled rules claim the same file.
    private nonisolated static func reportAmbiguousMatch(file: URL, competing: [AutoOrganizationRule]) {
        let detail = competing
            .map { "[\($0.conditionType.rawValue) '\($0.conditionValue)' → \($0.destinationURL.path)]" }
            .joined(separator: " ")
        ErrorReporter.report(
            AmbiguousRuleMatch(),
            context: "Auto-organization: \(file.lastPathComponent) matched by \(competing.count) enabled rules; first wins. Competing: \(detail)")
    }

    /// One detached task processes every match sequentially, rather than fanning out a separate
    /// task (each holding the 150ms stability timer) per file. Runs off the main actor: the
    /// stability check sleeps, and FileSystemService.moveItem falls back to a synchronous
    /// copy+delete for cross-volume moves that would otherwise freeze the UI on large files.
    /// Rule moves are not added to any window's undo stack — the sheet says so.
    private func dispatchMoves(_ pending: [PendingMove]) {
        let stabilityWindow = fileStabilityWindow
        let service = self
        Task.detached(priority: .utility) {
            // Snapshot every file, wait the window once, then re-check each — so a 100-file dump
            // settles in O(1) window latency instead of O(n) serial 2s waits.
            let before = pending.map { Self.fileSnapshot($0.file) }
            try? await Task.sleep(for: stabilityWindow)
            for (index, move) in pending.enumerated() {
                guard Self.isStable(before[index], move.file) else {
                    continue // size or mtime changed (or vanished) → still being written — skip this round
                }
                // A cross-volume move is copy+delete, not an atomic rename — demand several more
                // consecutive unchanged windows so a stalled-then-resumed download isn't truncated
                // at the destination (LL-063).
                if !Self.sameVolume(move.file, move.destinationURL),
                   await !(Self.confirmStableAcrossExtraWindows(move.file, window: stabilityWindow)) {
                    continue
                }
                do {
                    // Unattended — no user to prompt on a name collision, so keep both (unique-rename)
                    // rather than overwrite. See C1/H3.
                    _ = try await FileSystemService.moveItem(at: move.file, toFolder: move.destinationURL, onCollision: .keepBoth)
                    await MainActor.run { service.recordSuccessfulMove(ruleID: move.ruleID) }
                } catch {
                    // Unexpected failure — user has no other way to learn this move silently
                    // failed, since it runs unattended from background file monitoring.
                    ErrorReporter.report(error, context: "Auto-organization: moving file to rule destination")
                }
            }
        }
    }

    /// A file is considered "still being written" if its size changes across a short window.
    /// Deliberately not a lock check (FileHandle open / POSIX advisory lock): most writers —
    /// browsers, curl, Finder copies — never take an advisory lock on the file they're writing, so
    /// a lock-based check would never actually detect an in-progress download.
    ///
    /// Size + modification date, compared across `fileStabilityWindow` to tell "done writing" from
    /// "paused mid-write". `nonisolated` so the detached move task can stat without hopping to the
    /// main actor.
    private nonisolated static func fileSnapshot(_ url: URL) -> FileWriteSnapshot? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return nil }
        return FileWriteSnapshot(size: size, modified: attrs[.modificationDate] as? Date)
    }

    /// A file is safe to move only if it existed at both ends of the stability window with an
    /// identical size + mtime snapshot.
    private nonisolated static func isStable(_ before: FileWriteSnapshot?, _ url: URL) -> Bool {
        guard let before, let after = fileSnapshot(url) else { return false }
        return before == after
    }

    /// `true` only if `url`'s snapshot stays identical across `crossVolumeExtraStableWindows` more
    /// back-to-back `window`s. Used before a cross-volume auto-move (LL-063).
    nonisolated static func confirmStableAcrossExtraWindows(_ url: URL, window: Duration) async -> Bool {
        for _ in 0 ..< crossVolumeExtraStableWindows {
            let before = fileSnapshot(url)
            try? await Task.sleep(for: window)
            guard isStable(before, url) else { return false }
        }
        return true
    }

    /// Whether `a` and `b` live on the same mounted volume — a same-volume `moveItem` is an atomic
    /// rename, a cross-volume one is a non-atomic copy+delete. Compares `b`'s parent directory,
    /// since `b` (the destination file) doesn't exist yet.
    nonisolated static func sameVolume(_ lhs: URL, _ rhs: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.volumeIdentifierKey]
        let volA = try? lhs.resourceValues(forKeys: keys).volumeIdentifier
        let volB = try? rhs.deletingLastPathComponent().resourceValues(forKeys: keys).volumeIdentifier
        guard let volA, let volB else { return false } // unknown → treat as cross-volume (safer)
        return volA.isEqual(volB)
    }

    private struct FileWriteSnapshot: Equatable {
        let size: Int64
        let modified: Date?
    }

    private nonisolated static func matches(file: URL, rule: AutoOrganizationRule) -> Bool {
        let name = file.lastPathComponent
        let ext = file.pathExtension

        switch rule.conditionType {
        case .extensionEquals:
            return ext.caseInsensitiveCompare(rule.conditionValue) == .orderedSame
        case .nameContains:
            return name.localizedCaseInsensitiveContains(rule.conditionValue)
        case .namePrefix:
            guard !rule.conditionValue.isEmpty else { return false }
            return name.range(of: rule.conditionValue, options: [.caseInsensitive, .anchored]) != nil
        }
    }
}
