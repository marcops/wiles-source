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
        var owner: String?
        var group: String?
        var permsString: String?
        var dims: String?
        var duration: String?
        var kind: String?

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
            if let width = MDItemCopyAttribute(mdItem, kMDItemPixelWidth) as? Int,
               let height = MDItemCopyAttribute(mdItem, kMDItemPixelHeight) as? Int {
                dims = "\(width) × \(height)"
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

    public func streamBatchProperties(for urls: [URL]) -> AsyncStream<DetailedFileProperties> {
        AsyncStream { continuation in
            Task {
                for url in urls {
                    let props = fetchProperties(for: url)
                    continuation.yield(props)
                }
                continuation.finish()
            }
        }
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
