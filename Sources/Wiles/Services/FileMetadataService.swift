import Foundation
import CoreServices
import AppKit

public struct DetailedFileProperties: Sendable {
    public let url: URL
    public let ownerName: String?
    public let groupName: String?
    public let posixPermissions: String?
    public let dimensions: String?
    public let duration: String?
    public let kind: String?
}

public actor FileMetadataService {
    public static let shared = FileMetadataService()
    
    public func fetchProperties(for url: URL) -> DetailedFileProperties {
        var owner: String? = nil
        var group: String? = nil
        var permsString: String? = nil
        var dims: String? = nil
        var duration: String? = nil
        var kind: String? = nil
        
        let keys: Set<URLResourceKey> = [.localizedTypeDescriptionKey]
        if let values = try? url.resourceValues(forKeys: keys) {
            kind = values.localizedTypeDescription
        }
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            owner = attrs[.ownerAccountName] as? String
            group = attrs[.groupOwnerAccountName] as? String
            if let posix = attrs[.posixPermissions] as? NSNumber {
                permsString = formatPermissions(posix.intValue)
            }
        }
        
        if let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) {
            if let w = MDItemCopyAttribute(mdItem, kMDItemPixelWidth) as? Int,
               let h = MDItemCopyAttribute(mdItem, kMDItemPixelHeight) as? Int {
                dims = "\(w) × \(h)"
            }
            if let dur = MDItemCopyAttribute(mdItem, kMDItemDurationSeconds) as? Double {
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.unitsStyle = .abbreviated
                duration = formatter.string(from: dur)
            }
        }
        
        return DetailedFileProperties(
            url: url,
            ownerName: owner,
            groupName: group,
            posixPermissions: permsString,
            dimensions: dims,
            duration: duration,
            kind: kind
        )
    }
    
    private func formatPermissions(_ posix: Int) -> String {
        let roles = [
            (posix >> 6) & 0x7,
            (posix >> 3) & 0x7,
            posix & 0x7
        ]
        var result = ""
        for role in roles {
            result += (role & 4) != 0 ? "r" : "-"
            result += (role & 2) != 0 ? "w" : "-"
            result += (role & 1) != 0 ? "x" : "-"
        }
        return result
    }
}
