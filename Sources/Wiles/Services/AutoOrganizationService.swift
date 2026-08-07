import Foundation
import AppKit

@MainActor
public class AutoOrganizationService {
    public static let shared = AutoOrganizationService()

    private let rulesKey = DefaultsKey.autoOrganizationRules.rawValue

    public var rules: [AutoOrganizationRule] = [] {
        didSet {
            saveRules()
            restartMonitoring()
        }
    }

    private var fileMonitors: [String: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [String: CInt] = [:]
    /// Debounces rapid-fire `.write` events on a watched folder (e.g. a browser writing a large
    /// download incrementally can fire this thousands of times) into a single processFolder() call
    /// after activity settles, instead of re-scanning the whole directory on every single write.
    private var pendingScans: [String: DispatchWorkItem] = [:]
    private let scanDebounceInterval: TimeInterval = 0.5
    /// How long a matched file's size must stay unchanged before it's considered done writing and
    /// safe to move. FileHandle/POSIX lock checks don't work for this: most writers (browsers,
    /// curl, Finder copies) never take an advisory lock, so a locked-file check would never detect
    /// an in-progress download — size stability is what actually reflects "still being written to."
    private let stabilityCheckDelay: UInt64 = 150_000_000

    private init() {
        loadRules()
    }

    public func startMonitoring() {
        restartMonitoring()
    }

    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let loaded = try? JSONDecoder().decode([AutoOrganizationRule].self, from: data) {
            self.rules = loaded
        }
    }

    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
    }

    public func addRule(_ rule: AutoOrganizationRule) {
        rules.append(rule)
    }

    public func updateRule(_ rule: AutoOrganizationRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        }
    }

    public func deleteRule(id: UUID) {
        rules.removeAll(where: { $0.id == id })
    }

    private func restartMonitoring() {
        // Stop existing
        for (_, source) in fileMonitors {
            source.cancel()
        }
        for (_, fd) in fileDescriptors {
            close(fd)
        }
        fileMonitors.removeAll()
        fileDescriptors.removeAll()
        for (_, workItem) in pendingScans {
            workItem.cancel()
        }
        pendingScans.removeAll()

        let activeRules = rules.filter { $0.isEnabled }
        let uniqueSourceFolders = Set(activeRules.map { $0.sourceURL.standardizedFileURL })

        for folder in uniqueSourceFolders {
            startWatching(folder: folder)
        }
    }

    private func startWatching(folder: URL) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)

        source.setEventHandler { [weak self] in
            self?.scheduleProcessFolder(folder)
        }

        source.setCancelHandler {
            close(fd)
        }

        fileDescriptors[folder.path] = fd
        fileMonitors[folder.path] = source
        source.resume()
    }

    /// Coalesces repeated `.write` events for the same folder into one processFolder() call,
    /// resetting the timer on every new event — so a file that's still actively growing keeps
    /// pushing the scan back instead of triggering one per write.
    func scheduleProcessFolder(_ folder: URL) {
        pendingScans[folder.path]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.processFolder(folder)
        }
        pendingScans[folder.path] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + scanDebounceInterval, execute: workItem)
    }

    public func processFolder(_ folder: URL) {
        let activeRules = rules.filter { $0.isEnabled && $0.sourceURL.standardizedFileURL == folder.standardizedFileURL }
        guard !activeRules.isEmpty else { return }

        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: resourceKeys, options: [.skipsSubdirectoryDescendants]) else {
            return
        }

        for file in files {
            // Ignore hidden files and directories
            if file.lastPathComponent.hasPrefix(".") { continue }
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
                Task.detached(priority: .utility) {
                    guard let sizeBefore = Self.fileSize(file) else { return }
                    try? await Task.sleep(nanoseconds: stabilityCheckDelay)
                    guard let sizeAfter = Self.fileSize(file), sizeBefore == sizeAfter else {
                        return // still being written — skip this round
                    }
                    do {
                        _ = try FileSystemService.moveItem(at: file, toFolder: destinationURL)
                        await MainActor.run {
                            UndoRedoService.shared.recordAction(.move(sourceURL: file, destinationURL: destinationURL.appendingPathComponent(file.lastPathComponent)))
                        }
                    } catch {
                        // Suppress silent failures during background file monitoring
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
