import Foundation

public enum BatchRenameService {
    public static func previewNewNames(items: [FileItem], mode: BatchRenameMode) -> [(original: FileItem, newName: String)] {
        items.enumerated().map { index, item in
            (original: item, newName: renamedName(for: item, index: index, mode: mode))
        }
    }

    private static func renamedName(for item: FileItem, index: Int, mode: BatchRenameMode) -> String {
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
            let formattedNum = String(format: "%0\(paddingDigits)d", num)
            newBaseName = prefix.isEmpty ? formattedNum : "\(prefix)_\(formattedNum)"
        case let .regex(pattern, template):
            if pattern.isEmpty {
                newBaseName = baseName
            } else if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: baseName.utf16.count)
                newBaseName = regex.stringByReplacingMatches(in: baseName, options: [], range: range, withTemplate: template)
            } else {
                newBaseName = baseName
            }
        }

        return item.isDirectory ? newBaseName : "\(newBaseName)\(extWithDot)"
    }

    /// Returns the offending pattern string when `mode` is a `.regex` mode whose non-empty pattern
    /// fails to compile, `nil` otherwise (non-regex modes, or a regex mode with an empty/valid
    /// pattern never need to abort the rename).
    private static func invalidRegexPattern(in mode: BatchRenameMode) -> String? {
        guard case let .regex(pattern, _) = mode, !pattern.isEmpty else { return nil }
        return (try? NSRegularExpression(pattern: pattern, options: [])) == nil ? pattern : nil
    }

    public static func performBatchRename(items: [FileItem], mode: BatchRenameMode) async throws -> BatchRenameResult {
        // previewNewNames silently falls back to the original base name for an invalid regex
        // pattern (that fallback is fine for the live preview text), but actually performing the
        // rename must not pretend the user didn't ask for anything - validate the pattern up front
        // and abort with a real error instead of silently no-op-renaming every item.
        if let invalidPattern = invalidRegexPattern(in: mode) {
            throw WilesError.operationFailed(reason: "Invalid rename pattern: \(invalidPattern)")
        }

        let previews = previewNewNames(items: items, mode: mode)

        var renamedURLs: [URL] = []
        renamedURLs.reserveCapacity(previews.count)
        var renamedPairs: [(old: URL, new: URL)] = []
        var failures: [(item: FileItem, error: any Error)] = []
        for (item, newName) in previews {
            guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, newName != item.name else {
                renamedURLs.append(item.url)
                continue
            }
            do {
                let newURL = try await FileSystemService.renameItem(at: item.url, newName: newName)
                renamedURLs.append(newURL)
                renamedPairs.append((old: item.url, new: newURL))
            } catch {
                failures.append((item, error))
            }
        }
        return BatchRenameResult(renamedURLs: renamedURLs, renamedPairs: renamedPairs, failures: failures)
    }
}
