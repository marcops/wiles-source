import Foundation

public enum BatchRenameMode: Sendable {
    case replace(find: String, replaceWith: String)
    case addPrefixSuffix(prefix: String, suffix: String)
    case sequenceNumber(prefix: String, startNumber: Int, paddingDigits: Int)
}

public final class BatchRenameService {
    public static func previewNewNames(items: [FileItem], mode: BatchRenameMode) -> [(original: FileItem, newName: String)] {
        return items.enumerated().map { index, item in
            let ext = item.fileExtension
            let extWithDot = ext.isEmpty ? "" : ".\(ext)"
            let baseName = item.isDirectory ? item.name : item.url.deletingPathExtension().lastPathComponent
            
            let newBaseName: String
            switch mode {
            case .replace(let find, let replaceWith):
                if find.isEmpty {
                    newBaseName = baseName
                } else {
                    newBaseName = baseName.replacingOccurrences(of: find, with: replaceWith)
                }
            case .addPrefixSuffix(let prefix, let suffix):
                newBaseName = "\(prefix)\(baseName)\(suffix)"
            case .sequenceNumber(let prefix, let startNumber, let paddingDigits):
                let num = startNumber + index
                let formattedNum = String(format: "%0\(paddingDigits)d", num)
                newBaseName = prefix.isEmpty ? formattedNum : "\(prefix)_\(formattedNum)"
            }
            
            let finalName = item.isDirectory ? newBaseName : "\(newBaseName)\(extWithDot)"
            return (original: item, newName: finalName)
        }
    }
    
    public static func performBatchRename(items: [FileItem], mode: BatchRenameMode) throws -> [URL] {
        let previews = previewNewNames(items: items, mode: mode)
        var renamedURLs: [URL] = []
        
        for (item, newName) in previews {
            guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, newName != item.name else {
                renamedURLs.append(item.url)
                continue
            }
            let newURL = try FileSystemService.renameItem(at: item.url, newName: newName)
            renamedURLs.append(newURL)
        }
        
        return renamedURLs
    }
}
