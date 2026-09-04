import AppKit
import Foundation

@MainActor
public struct NetworkServerService {
    /// Injectable seam for tests — see `WorkspaceOpening`. Defaults to the real `NSWorkspace`.
    public static var opener: any WorkspaceOpening = RealWorkspaceOpener()

    public static func connectToServer(urlAddress: String) throws {
        let trimmed = urlAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let fullAddress = trimmed.contains("://") ? trimmed : "smb://\(trimmed)"

        guard let url = serverURL(fromFullAddress: fullAddress) else {
            throw WilesError.localized(key: .invalidServerURL, arguments: [])
        }

        guard opener.open(url) else {
            throw WilesError.localized(key: .serverConnectionFailed, arguments: [fullAddress])
        }
    }

    /// Parses a `scheme://host/share…` address into a `URL`. A share name legitimately contains
    /// spaces ("smb://nas/Time Machine Backups"), which `URL(string:)` rejects outright — so a
    /// literal-space fallback percent-encodes them rather than failing a valid target.
    static func serverURL(fromFullAddress fullAddress: String) -> URL? {
        if let direct = URL(string: fullAddress) {
            return direct
        }
        return URL(string: fullAddress.replacingOccurrences(of: " ", with: "%20"))
    }
}
