import Foundation
import Observation

@Observable
@MainActor
public final class ModalStore {
    public var showSaveSmartFolderSheet: Bool = false
    public var showPasswordCompressSheet: Bool = false
    public var passwordCompressURLs: [URL]?
    public var inspectArchiveURL: URL?
    public var showArchiveInspectionSheet: Bool = false
    public var errorMessage: String?
    public var showErrorAlert: Bool = false
    public var showHelpSheet: Bool = false
    public var showAboutSheet: Bool = false

    public init() {}

    public func showError(_ message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
    }
}
