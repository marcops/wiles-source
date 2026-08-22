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
            throw NSError(domain: "NetworkServerService", code: 400, userInfo: [NSLocalizedDescriptionKey: L10n.string(.invalidServerURL, lang: .system)])
        }

        guard opener.open(url) else {
            throw NSError(
                domain: "NetworkServerService", code: 401,
                userInfo: [NSLocalizedDescriptionKey: String(format: L10n.string(.serverConnectionFailed, lang: .system), fullAddress)])
        }
    }
}
