import AppKit
import CoreServices
import Foundation
import GitBeacon

/// Detailed "Get Info" metadata reads. Stateless — each call does its own `Task.detached` hop off
/// the main actor; there's nothing to serialize, so it's a namespace, not an actor.
public enum FileMetadataService {
    public static func fetchProperties(for url: URL) async -> DetailedFileProperties {
        await Task.detached(priority: .userInitiated) {
            fetchPropertiesSync(for: url)
        }.value
    }

    private static func fetchPropertiesSync(for url: URL) -> DetailedFileProperties {
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

    private static func readTypeDescription(for url: URL) -> String? {
        let keys: Set<URLResourceKey> = [.localizedTypeDescriptionKey]
        do {
            let values = try url.resourceValues(forKeys: keys)
            return values.localizedTypeDescription
        } catch {
            ErrorReporter.report(error, context: "Reading resource values for \(url.path)")
            return nil
        }
    }

    private static func readOwnershipAndPermissions(
        for url: URL, owner: inout String?, group: inout String?, perms: inout String?) {
        let ownership = FilePermissionsService.ownership(of: url)
        owner = ownership.owner
        group = ownership.group
        perms = ownership.permissions?.symbolicString
    }

    private static func readSpotlightDimensionsAndDuration(for url: URL) -> (dims: String?, duration: String?) {
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

    public static func streamBatchProperties(for urls: [URL]) -> AsyncStream<DetailedFileProperties> {
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
                    let props = await fetchProperties(for: url)
                    continuation.yield(props)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
