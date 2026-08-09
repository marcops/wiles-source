import AppKit
import Observation

/// Tracks the Mac's actual current light/dark appearance, refreshed live when the user changes it
/// in System Settings while Wiles is running. Exists because SwiftUI's `.preferredColorScheme(nil)`
/// ("follow System") does not reliably get retroactively re-applied to an already-open `NSWindow`
/// once a concrete Light/Dark override has been set — only a genuinely non-nil value propagates
/// live. Resolving "System" to a concrete `.light`/`.dark` value ourselves means the app never has
/// to pass `nil` again, sidestepping that gap entirely by always going through the code path that's
/// already proven to work (explicit Light/Dark selection).
@MainActor
@Observable
public final class SystemAppearanceObserver {
    public static let shared = SystemAppearanceObserver()

    public private(set) var isDark: Bool
    // Stored (never discarded — see rule 21 in AGENTS.md) but intentionally never removed: this is
    // a permanent `.shared` singleton that lives for the entire app lifetime, same as
    // `ThumbnailService.shared`/`PermissionService`, so there's no teardown point to remove it at
    // and no risk of duplicate registration since `init()` only ever runs once.
    private let observerToken: NSObjectProtocol

    private init() {
        isDark = Self.currentIsDark()
        observerToken = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                SystemAppearanceObserver.shared.isDark = Self.currentIsDark()
            }
        }
    }

    private static func currentIsDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
