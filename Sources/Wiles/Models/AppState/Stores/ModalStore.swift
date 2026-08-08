import Foundation
import Observation

@Observable
@MainActor
public final class ModalStore {
    public var errorMessage: String?
    public var showErrorAlert: Bool = false

    public init() {}

    public func showError(_ message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
    }
}
