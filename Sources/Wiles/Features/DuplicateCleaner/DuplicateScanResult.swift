import Foundation

public struct DuplicateScanResult: Sendable {
    public let groups: [DuplicateGroup]
    public let totalReclaimableBytes: Int64
    /// True if the scan hit `maxScannedFileCount` — results may be incomplete.
    public let wasTruncated: Bool

    public init(groups: [DuplicateGroup], totalReclaimableBytes: Int64, wasTruncated: Bool = false) {
        self.groups = groups
        self.totalReclaimableBytes = totalReclaimableBytes
        self.wasTruncated = wasTruncated
    }
}
