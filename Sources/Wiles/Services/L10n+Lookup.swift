import Foundation

public extension L10n {
    static func activeCode(_ preferred: AppLanguage, systemPreferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if preferred != .system {
            return preferred.rawValue
        }
        // `.system` itself is not a locale — only real language codes are match candidates.
        let supportedCodes = AppLanguage.allCases.filter { $0 != .system }.map(\.rawValue)
        for preference in systemPreferredLanguages {
            let lower = preference.lowercased()
            // Exact or region-variant of a supported code (en-GB → en, zh-Hans-CN → zh-Hans).
            if let match = supportedCodes.first(where: { lower == $0.lowercased() || lower.hasPrefix($0.lowercased() + "-") }) {
                return match
            }
            // Otherwise the same language family (zh / zh-Hant → zh-Hans; the only zh we ship).
            let family = lower.split(separator: "-").first
            if let match = supportedCodes.first(where: { $0.lowercased().split(separator: "-").first == family }) {
                return match
            }
        }
        return "en"
    }

    private static var resourceBundle: Bundle {
        .wilesResources
    }

    // Called on every label/tooltip/menu lookup, so the per-language `Bundle(path:)` resolution
    // (a directory read on every call) is cached here — locked since callers span threads.
    private static let bundleCacheLock = NSLock()
    private nonisolated(unsafe) static var bundleCache: [String: Bundle] = [:]

    private static func langBundle(forCode code: String) -> Bundle? {
        bundleCacheLock.lock()
        defer { bundleCacheLock.unlock() }
        if let cached = bundleCache[code] {
            return cached
        }
        guard let path = resourceBundle.path(forResource: code, ofType: "lproj") ?? resourceBundle.path(forResource: code.lowercased(), ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        bundleCache[code] = bundle
        return bundle
    }

    static func string(_ key: Key, lang: AppLanguage) -> String {
        let code = activeCode(lang)
        if let langBundle = langBundle(forCode: code) {
            return langBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
        }
        return resourceBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
    }
}
