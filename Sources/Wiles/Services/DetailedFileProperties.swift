import Foundation

public struct DetailedFileProperties: Sendable {
    public let url: URL
    public let ownerName: String?
    public let groupName: String?
    public let posixPermissions: String?
    public let dimensions: String?
    public let duration: String?
    public let kind: String?
}
