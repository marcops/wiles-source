import Foundation
import Observation

/// Appearance-related preferences: light/dark mode, app language, and the translucency levels
/// (plus the opacity math derived from them). Split out of `PreferencesStore` (SRP).
@Observable
@MainActor
public final class AppearancePreferences: PersistablePreferenceStore {
    @ObservationIgnored var isRestoringDefaults = false

    public var appAppearance: AppAppearance = .system {
        didSet { guard !isRestoringDefaults else { return }
            persist(appAppearance, .appAppearance)
        }
    }

    public var appLanguage: AppLanguage = .system {
        didSet { guard !isRestoringDefaults else { return }
            persist(appLanguage, .appLanguage)
        }
    }

    public var sidebarTranslucentLevel: Int = 80 {
        didSet { guard !isRestoringDefaults else { return }
            persist(sidebarTranslucentLevel, .sidebarTranslucentLevel)
        }
    }

    public var contentTranslucentLevel: Int = 40 {
        didSet { guard !isRestoringDefaults else { return }
            persist(contentTranslucentLevel, .contentTranslucentLevel)
        }
    }

    /// Light mode's window is already brighter, so the translucency overlay is dialed back to
    /// avoid washing content out.
    private static let lightModeOverlayDamping = 0.5

    public var sidebarOverlayOpacity: Double {
        let base = 1.0 - Double(sidebarTranslucentLevel) / 100.0
        return appAppearance == .light ? base * Self.lightModeOverlayDamping : base
    }

    public var contentOverlayOpacity: Double {
        let base = 1.0 - Double(contentTranslucentLevel) / 100.0
        return appAppearance == .light ? base * Self.lightModeOverlayDamping : base
    }

    public init() {
        let defaults = UserDefaults.standard
        loadEnum(.appAppearance, into: \.appAppearance, from: defaults)
        loadEnum(.appLanguage, into: \.appLanguage, from: defaults)

        let sLevel = defaults.integer(forKey: DefaultsKey.sidebarTranslucentLevel.rawValue)
        if sLevel > 0 {
            sidebarTranslucentLevel = sLevel
        }
        let cLevel = defaults.integer(forKey: DefaultsKey.contentTranslucentLevel.rawValue)
        if cLevel > 0 {
            contentTranslucentLevel = cLevel
        }
    }
}
