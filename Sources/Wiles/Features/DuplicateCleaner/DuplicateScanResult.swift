import Foundation

public struct DuplicateScanResult: Sendable {
    public let groups: [DuplicateGroup]
    public let totalReclaimableBytes: Int64
}
