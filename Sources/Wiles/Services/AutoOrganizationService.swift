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
    /// This service has no owning window (a background scan can fire with no window focused), so
    /// its own moves are recorded on their own instance rather than any one window's `AppState`.
    let undoRedoService = UndoRedoService()
    /// How long a matched file's size must stay unchanged before it's considered done writing and
    /// safe to move. FileHandle/POSIX lock checks don't work for this: most writers (browsers,
    /// curl, Finder copies) never take an advisory lock, so a locked-file check would never detect
    /// an in-progress download — size stability is what actually reflects "still being written to."
    private let stabilityCheckDelay: UInt64 = 150_000_000

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

    private func restartMonitoring() {
        let activeRules = rules.filter(\.isEnabled)
        let uniqueSourceFolders = Set(activeRules.map(\.sourceURL.standardizedFileURL))
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
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: resourceKeys, options: [.skipsSubdirectoryDescendants]) else {
                return
            }
            await self?.matchAndDispatchMoves(folder: folder, files: files, resourceKeys: resourceKeys)
        }
    }

    /// Runs on the main actor: re-filters the current rules against `folder` (rules may have
    /// changed while the detached scan above was in flight) and matches the freshly-scanned
    /// `files`, dispatching each match's move exactly as before. Split out of `processFolder` only
    /// so the initial (potentially slow, /Volumes-backed) directory scan can run detached.
    private func matchAndDispatchMoves(folder: URL, files: [URL], resourceKeys: [URLResourceKey]) {
        let activeRules = rules.filter { $0.isEnabled && $0.sourceURL.standardizedFileURL == folder.standardizedFileURL }
        guard !activeRules.isEmpty else { return }

        for file in files {
            // Ignore hidden files and directories
            if file.lastPathComponent.hasPrefix(".") {
                continue
            }
            let resourceValues = try? file.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues?.isDirectory == true {
                continue
            }

            for rule in activeRules where matches(file: file, rule: rule) {
                // Move file natively using UndoRedoService for safe undo.
                // Runs detached off the main actor: the stability check sleeps, and
                // FileSystemService.moveItem falls back to a synchronous copy+delete for
                // cross-volume moves, which would otherwise freeze the UI on large files.
                let stabilityCheckDelay = self.stabilityCheckDelay
                let destinationURL = rule.destinationURL
                let undoRedoService = self.undoRedoService
                Task.detached(priority: .utility) {
                    guard let sizeBefore = Self.fileSize(file) else { return }
                    try? await Task.sleep(nanoseconds: stabilityCheckDelay)
                    guard let sizeAfter = Self.fileSize(file), sizeBefore == sizeAfter else {
                        return // still being written — skip this round
                    }
                    do {
                        _ = try FileSystemService.moveItem(at: file, toFolder: destinationURL)
                        await MainActor.run {
                            undoRedoService.recordAction(.move(
                                sourceURL: file,
                                destinationURL: destinationURL.appendingPathComponent(file.lastPathComponent)))
                        }
                    } catch {
                        // Unexpected failure — user has no other way to learn this move silently
                        // failed, since it runs unattended from background file monitoring.
                        ErrorReporter.report(error, context: "Auto-organization: moving file to rule destination")
                    }
                }
                break // Stop checking other rules for this file if one matched
            }
        }
    }

    /// A file is considered "still being written" if its size changes across a short window.
    /// Deliberately not a lock check (FileHandle open / POSIX advisory lock): most writers —
    /// browsers, curl, Finder copies — never take an advisory lock on the file they're writing, so
    /// a lock-based check would never actually detect an in-progress download.
    ///
    /// `nonisolated` so it can run from the detached move task below without hopping onto the
    /// main actor for a plain filesystem stat call.
    private nonisolated static func fileSize(_ url: URL) -> Int64? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
    }

    private func matches(file: URL, rule: AutoOrganizationRule) -> Bool {
        let name = file.lastPathComponent
        let ext = file.pathExtension

        switch rule.conditionType {
        case .extensionEquals:
            return ext.caseInsensitiveCompare(rule.conditionValue) == .orderedSame
        case .nameContains:
            return name.localizedCaseInsensitiveContains(rule.conditionValue)
        case .namePrefix:
            return name.lowercased().hasPrefix(rule.conditionValue.lowercased())
        }
    }
}
