import Foundation
import AppKit
import UniformTypeIdentifiers

/// macOS reserves double-click-to-open behavior for folders exclusively to Finder — there is no
/// public API for a third-party app to become the default handler invoked when a folder is
/// double-clicked anywhere in the system. `NSWorkspace.setDefaultApplication(at:toOpen:)` for
/// `public.folder` is the only relevant public hook: at best it lets Wiles appear as an option in
/// Finder's "Open With" submenu for folders. It cannot replace Finder as the double-click default.
public enum DefaultFolderHandlerService {
    @MainActor
    public static func registerAsFolderHandlerOption(completion: @escaping @Sendable (Bool) -> Void = { _ in }) {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .folder) { error in
            completion(error == nil)
        }
    }
}
