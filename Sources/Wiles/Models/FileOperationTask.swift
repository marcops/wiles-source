import Foundation

public struct FileOperationTask: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public var bytesTransferred: Int64
    public var totalBytes: Int64

    /// Derived rather than stored so it can never diverge from the byte counts it's meant to reflect.
    public var progress: Double {
        totalBytes > 0 ? Double(bytesTransferred) / Double(totalBytes) : 0
    }

    public init(
        id: UUID = UUID(),
        title: String,
        bytesTransferred: Int64 = 0,
        totalBytes: Int64 = 0) {
        self.id = id
        self.title = title
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
    }
}
