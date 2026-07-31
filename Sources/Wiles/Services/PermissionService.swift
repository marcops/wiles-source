import Foundation

public struct PermissionService: Sendable {
    private static let hasRequestedKey = "wiles_hasRequestedInitialPermissions"
    
    /// Requests macOS system permissions (TCC) for user directories ONLY ONCE on initial launch.
    /// Prevents prompting the user repeatedly on every application startup.
    public static func requestInitialPermissions() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: hasRequestedKey) {
            return
        }
        defaults.set(true, forKey: hasRequestedKey)
        
        let fm = FileManager.default
        let folders: [URL] = [
            fm.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            fm.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fm.urls(for: .musicDirectory, in: .userDomainMask).first,
            fm.urls(for: .picturesDirectory, in: .userDomainMask).first,
            fm.urls(for: .moviesDirectory, in: .userDomainMask).first
        ].compactMap { $0 }
        
        Task.detached(priority: .userInitiated) {
            for folder in folders {
                _ = try? fm.contentsOfDirectory(atPath: folder.path)
            }
        }
    }
    
    /// Resets initial permission flag if needed for testing or user request.
    public static func resetInitialPermissionsFlag() {
        UserDefaults.standard.removeObject(forKey: hasRequestedKey)
    }
}

