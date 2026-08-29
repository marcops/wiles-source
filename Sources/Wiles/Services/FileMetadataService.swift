import AppKit
import CoreServices
import Foundation
import GitBeacon

public actor FileMetadataService {
    public static let shared = FileMetadataService()

    public func fetchProperties(for url: URL) -> DetailedFileProperties {
        let kind = readTypeDescription(for: url)
        var owner: String?
        var group: String?
        var permsString: String?
        readOwnershipAndPermissions(for: url, owner: &owner, group: &group, perms: &permsString)
        let (dims, duration) = readSpotlightDimensionsAndDuration(for: url)

        return DetailedFileProperties(
            url: url,
            ownerName: owner,
            groupName: group,
            posixPermissions: permsString,
            dimensions: dims,
            duration: duration,
            kind: kind)
    }

    private func readTypeDescription(for url: URL) -> String? {
        let keys: Set<URLResourceKey> = [.localizedTypeDescriptionKey]
        do {
            let values = try url.resourceValues(forKeys: keys)
            return values.localizedTypeDescription
        } catch {
            ErrorReporter.report(error, context: "Reading resource values for \(url.path)")
            return nil
        }
    }

    private func readOwnershipAndPermissions(
        for url: URL, owner: inout String?, group: inout String?, perms: inout String?) {
        // Same owner/perms attributes are read separately by FilePermissionsService and FileItem.ownerAndGroup.
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            owner = attrs[.ownerAccountName] as? String
            group = attrs[.groupOwnerAccountName] as? String
            perms = (attrs[.posixPermissions] as? NSNumber).map { formatPermissions($0.intValue) }
        } catch {
            ErrorReporter.report(error, context: "Reading file attributes for \(url.path)")
        }
    }

    private func readSpotlightDimensionsAndDuration(for url: URL) -> (dims: String?, duration: String?) {
        guard let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else {
            return (nil, nil)
        }
        var dims: String?
        var duration: String?
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
        return (dims, duration)
    }

    public func streamBatchProperties(for urls: [URL]) -> AsyncStream<DetailedFileProperties> {
        AsyncStream { continuation in
            let task = Task {
                for url in urls {
                    // Consuming a stream is exactly how a caller signals "I stopped waiting" — a
                    // `for await` loop that `break`s, or its own enclosing Task being cancelled,
                    // triggers onTermination below. Without this check, closing the properties
                    // sheet mid-scan would leave this loop reading disk metadata for the rest of
                    // the (possibly huge) URL list in the background, for nobody.
                    if Task.isCancelled {
                        break
                    }
                    let props = fetchProperties(for: url)
                    continuation.yield(props)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
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
