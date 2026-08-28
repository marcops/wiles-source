import AppKit
import Foundation

@MainActor
public struct NetworkServerService {
    /// Injectable seam for tests — see `WorkspaceOpening`. Defaults to the real `NSWorkspace`.
    public static var opener: any WorkspaceOpening = RealWorkspaceOpener()

    public static func connectToServer(urlAddress: String) throws {
        let trimmed = urlAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let fullAddress: String = if trimmed.contains("://") {
            trimmed
        } else {
            "smb://\(trimmed)"
        }

        guard let url = URL(string: fullAddress) else {
            throw WilesError.localized(key: .invalidServerURL, arguments: [])
        }

        guard opener.open(url) else {
            throw WilesError.localized(key: .serverConnectionFailed, arguments: [fullAddress])
        }
    }
}
