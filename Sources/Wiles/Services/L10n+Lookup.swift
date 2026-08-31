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
            // `value: ""` (not `key.rawValue`): `localizedString` returns `value` verbatim on a
            // miss, so this comes back empty when `<code>.lproj` exists but lacks this key — rather
            // than returning the raw enum name (`"shortcutsAllTab"`) straight to the UI. Degrade to
            // the English string instead; only a key absent from *every* locale falls through to
            // the identifier below (finding ML-138).
            let localized = langBundle.localizedString(forKey: key.rawValue, value: "", table: nil)
            if !localized.isEmpty {
                return localized
            }
        }
        return resourceBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
    }
}
