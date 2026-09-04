import Foundation

public enum BatchRenameService {
    private static let minPaddingDigits = 1
    private static let maxPaddingDigits = 10

    /// Outcome of compiling a mode's regex pattern once, shared by the live preview (which tolerates
    /// `.invalid` as "leave names untouched") and `performBatchRename` (which turns it into a thrown
    /// error). `.none` covers non-regex modes and an empty pattern.
    private enum RegexResolution {
        case none
        case compiled(NSRegularExpression)
        case invalid(pattern: String)

        var regex: NSRegularExpression? {
            if case let .compiled(regex) = self {
                return regex
            }
            return nil
        }
    }

    private static func resolveRegex(for mode: BatchRenameMode) -> RegexResolution {
        guard case let .regex(pattern, _) = mode, !pattern.isEmpty else { return .none }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return .invalid(pattern: pattern)
        }
        return .compiled(regex)
    }

    public static func previewNewNames(items: [FileItem], mode: BatchRenameMode) -> [(original: FileItem, newName: String)] {
        previewNewNames(items: items, mode: mode, regex: resolveRegex(for: mode).regex)
    }

    /// Shared core — the regex is compiled once by the caller (not once per item; a 500-item
    /// `.regex` preview used to build 500 `NSRegularExpression`s on every keystroke).
    private static func previewNewNames(
        items: [FileItem], mode: BatchRenameMode, regex: NSRegularExpression?) -> [(original: FileItem, newName: String)] {
        items.enumerated().map { index, item in
            (original: item, newName: renamedName(for: item, index: index, mode: mode, regex: regex))
        }
    }

    private static func renamedName(for item: FileItem, index: Int, mode: BatchRenameMode, regex: NSRegularExpression?) -> String {
        let ext = item.fileExtension
        let extWithDot = ext.isEmpty ? "" : ".\(ext)"
        let baseName = item.isDirectory ? item.name : item.url.deletingPathExtension().lastPathComponent

        let newBaseName: String
        switch mode {
        case let .replace(find, replaceWith):
            if find.isEmpty {
                newBaseName = baseName
            } else {
                newBaseName = baseName.replacingOccurrences(of: find, with: replaceWith)
            }
        case let .addPrefixSuffix(prefix, suffix):
            newBaseName = "\(prefix)\(baseName)\(suffix)"
        case let .sequenceNumber(prefix, startNumber, paddingDigits):
            let num = startNumber + index
            // Don't trust the caller's width - a negative or 0 value yields a malformed format string.
            let safePadding = min(max(paddingDigits, minPaddingDigits), maxPaddingDigits)
            let formattedNum = String(format: "%0\(safePadding)d", num)
            newBaseName = prefix.isEmpty ? formattedNum : "\(prefix)_\(formattedNum)"
        case let .regex(_, template):
            if let regex {
                let range = NSRange(location: 0, length: baseName.utf16.count)
                newBaseName = regex.stringByReplacingMatches(in: baseName, options: [], range: range, withTemplate: template)
            } else {
                // Empty or invalid pattern: leave the name untouched (matches the prior fallback).
                newBaseName = baseName
            }
        }

        return item.isDirectory ? newBaseName : "\(newBaseName)\(extWithDot)"
    }

    /// `true` when `newName` is non-blank and differs from the item's current name (a real rename).
    private static func isActualRename(_ item: FileItem, to newName: String) -> Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && newName != item.name
    }

    /// Pure pre-flight collision check: returns every target name claimed by 2+ items in the batch,
    /// plus every target already on disk that isn't itself being renamed away by this batch.
    public static func validateTargets(
        targetNames: [String],
        renamedOriginalNames: Set<String>,
        directoryContents: Set<String>) -> [BatchRenameConflict] {
        var counts: [String: Int] = [:]
        for name in targetNames {
            counts[name, default: 0] += 1
        }

        var conflicts: [BatchRenameConflict] = []
        var handled: Set<String> = []
        for name in targetNames where handled.insert(name).inserted {
            if counts[name, default: 0] > 1 {
                conflicts.append(BatchRenameConflict(targetName: name, kind: .duplicateWithinBatch))
            } else if isPreexistingCollision(name, renamedOriginalNames: renamedOriginalNames, directoryContents: directoryContents) {
                conflicts.append(BatchRenameConflict(targetName: name, kind: .existsOnDisk))
            }
        }
        return conflicts
    }

    private static func isPreexistingCollision(
        _ name: String,
        renamedOriginalNames: Set<String>,
        directoryContents: Set<String>) -> Bool {
        directoryContents.contains(name) && !renamedOriginalNames.contains(name)
    }

    /// Throws if any target collides, so the executing loop can't fail an item mid-way with a raw
    /// `NSFileWriteFileExistsError`. Grouped by source directory since a batch may span folders.
    private static func assertNoCollisions(in previews: [(original: FileItem, newName: String)]) throws {
        let renames = previews.filter { isActualRename($0.original, to: $0.newName) }
        guard !renames.isEmpty else { return }
        let byDirectory = Dictionary(grouping: renames) { $0.original.url.deletingLastPathComponent() }
        for (directory, group) in byDirectory {
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            let conflicts = validateTargets(
                targetNames: group.map(\.newName),
                renamedOriginalNames: Set(group.map(\.original.name)),
                directoryContents: Set(contents))
            guard conflicts.isEmpty else {
                let names = conflicts.map(\.targetName).joined(separator: ", ")
                throw WilesError.localized(key: .batchRenameWouldCollide, arguments: [names])
            }
        }
    }

    public static func performBatchRename(items: [FileItem], mode: BatchRenameMode) async throws -> BatchRenameResult {
        // previewNewNames silently falls back to the original base name for an invalid regex
        // pattern (that fallback is fine for the live preview text), but actually performing the
        // rename must not pretend the user didn't ask for anything - validate the pattern up front
        // and abort with a real error instead of silently no-op-renaming every item. Compiled once
        // here and threaded into the preview, not compiled a second time.
        let resolution = resolveRegex(for: mode)
        if case let .invalid(pattern) = resolution {
            throw WilesError.localized(key: .batchRenameInvalidPattern, arguments: [pattern])
        }

        let previews = previewNewNames(items: items, mode: mode, regex: resolution.regex)
        try assertNoCollisions(in: previews)

        // De-hide any staging temps a previously crashed batch rename stranded in these folders
        // (MM-113): the temp IS the user's file, so it's renamed to a visible name, never deleted.
        await recoverStrandedStagingTemps(in: Set(items.map { $0.url.deletingLastPathComponent() }))

        // A permutation (swap A↔B, rotate A→B→C→A) passes `assertNoCollisions` but the sequential
        // rename below would fail every step — the target name is still occupied by another source.
        // Stage those sources through a unique temp name first so the finals are always free.
        let sourceURLByStaged = try await stagePermutationCycles(in: previews)
        return try await renameStagedPreviews(previews, sourceURLByStaged: sourceURLByStaged)
    }

    /// The sequential temp→final rename loop. Each staged original is cleared from `unresolvedStaged`
    /// as it resolves (renamed to its final name, or restored on failure); whatever's left when the
    /// loop exits early (cancellation) is restored so nothing is stranded under a hidden name (MM-113).
    private static func renameStagedPreviews(
        _ previews: [(original: FileItem, newName: String)],
        sourceURLByStaged: [URL: URL]) async throws -> BatchRenameResult {
        var renamedURLs: [URL] = []
        renamedURLs.reserveCapacity(previews.count)
        var renamedPairs: [(old: URL, new: URL)] = []
        var failures: [(item: FileItem, error: any Error)] = []
        var unresolvedStaged = sourceURLByStaged

        do {
            for (item, newName) in previews {
                try Task.checkCancellation()
                guard isActualRename(item, to: newName) else {
                    renamedURLs.append(item.url)
                    continue
                }
                let currentURL = sourceURLByStaged[item.url] ?? item.url
                do {
                    let newURL = try await FileSystemService.renameItem(at: currentURL, newName: newName)
                    renamedURLs.append(newURL)
                    renamedPairs.append((old: item.url, new: newURL))
                    unresolvedStaged[item.url] = nil
                } catch {
                    failures.append((item, error))
                    if currentURL != item.url {
                        _ = try? await FileSystemService.renameItem(
                            at: currentURL, newName: item.name, onCollision: .keepBoth)
                        unresolvedStaged[item.url] = nil
                    }
                }
            }
        } catch {
            await restoreStaged(unresolvedStaged)
            throw error
        }
        return BatchRenameResult(renamedURLs: renamedURLs, renamedPairs: renamedPairs, failures: failures)
    }

    /// Batch-rename staging temp prefix — the hidden name a participant is parked under between
    /// `stagePermutationCycles` and its final rename.
    static let stagingTempPrefix = ".wiles-batch-rename-"

    /// Renames every still-staged original (`originalURL → tempURL`) back to a visible name.
    static func restoreStaged(_ staged: [URL: URL]) async {
        for (originalURL, tempURL) in staged {
            _ = try? await FileSystemService.renameItem(
                at: tempURL, newName: originalURL.lastPathComponent, onCollision: .keepBoth)
        }
    }

    /// Renames any `.wiles-batch-rename-*` leftover older than a few seconds (i.e. from a crashed
    /// prior run, not this one's in-flight staging) to a visible `Recovered …` name so the user can
    /// find their file. Never deletes — the temp is the only copy (MM-113).
    static func recoverStrandedStagingTemps(in directories: Set<URL>) async {
        for directory in directories {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else { continue }
            for entry in entries where entry.lastPathComponent.hasPrefix(stagingTempPrefix) {
                let mtime = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                guard let mtime, Date().timeIntervalSince(mtime) > 5 else { continue }
                let suffix = entry.lastPathComponent.dropFirst(stagingTempPrefix.count)
                _ = try? await FileSystemService.renameItem(
                    at: entry, newName: "Recovered \(suffix)", onCollision: .keepBoth)
            }
        }
    }

    private struct StagedRename {
        let originalURL: URL
        let tempURL: URL
        let originalName: String
    }

    /// For each source directory whose set of new names overlaps its set of old names (a rename
    /// cycle), renames every participant to a unique hidden temp name up front. Returns
    /// `originalURL → temp URL` for those so the main loop renames the temp to the final name.
    private static func stagePermutationCycles(
        in previews: [(original: FileItem, newName: String)]) async throws -> [URL: URL] {
        try await stagePermutationCycles(
            pairs: previews
                .filter { isActualRename($0.original, to: $0.newName) }
                .map { (url: $0.original.url, newName: $0.newName) })
    }

    /// Lower-level form working on plain `(url, newName)` pairs so `UndoRedoService.undoBatch` can
    /// reuse it. Per directory whose targets overlap its sources, stages participants to a hidden temp.
    static func stagePermutationCycles(pairs: [(url: URL, newName: String)]) async throws -> [URL: URL] {
        let renames = pairs.filter {
            !$0.newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.newName != $0.url.lastPathComponent
        }
        let byDirectory = Dictionary(grouping: renames) { $0.url.deletingLastPathComponent() }

        var stagedURLByOriginal: [URL: URL] = [:]
        for (_, group) in byDirectory {
            let newNames = Set(group.map(\.newName))
            let oldNames = Set(group.map { $0.url.lastPathComponent })
            guard !newNames.isDisjoint(with: oldNames) else { continue }

            var stagedThisGroup: [StagedRename] = []
            do {
                for pair in group {
                    try Task.checkCancellation()
                    let tempName = "\(stagingTempPrefix)\(UUID().uuidString)"
                    let tempURL = try await FileSystemService.renameItem(at: pair.url, newName: tempName)
                    stagedThisGroup.append(
                        StagedRename(originalURL: pair.url, tempURL: tempURL, originalName: pair.url.lastPathComponent))
                }
            } catch {
                for entry in stagedThisGroup {
                    _ = try? await FileSystemService.renameItem(at: entry.tempURL, newName: entry.originalName)
                }
                throw error
            }
            for entry in stagedThisGroup {
                stagedURLByOriginal[entry.originalURL] = entry.tempURL
            }
        }
        return stagedURLByOriginal
    }
}
