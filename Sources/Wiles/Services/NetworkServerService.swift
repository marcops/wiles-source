import Foundation
import AppKit

public struct NetworkServerService: Sendable {
    public static func connectToServer(urlAddress: String) throws {
        let trimmed = urlAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let fullAddress: String
        if trimmed.contains("://") {
            fullAddress = trimmed
        } else {
            fullAddress = "smb://\(trimmed)"
        }

        guard let url = URL(string: fullAddress) else {
            throw NSError(domain: "NetworkServerService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"])
        }

        NSWorkspace.shared.open(url)
    }
}
