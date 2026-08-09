import Foundation

@MainActor
public protocol OpenWithServiceProtocol: Sendable {
    static func availableApplications(for url: URL) -> [ApplicationApp]
    static func open(urls: [URL], with applicationURL: URL)
    static func chooseOtherApplication(toOpen urls: [URL])
    static func setDefaultApplication(for fileExtension: String, applicationURL: URL)
}
