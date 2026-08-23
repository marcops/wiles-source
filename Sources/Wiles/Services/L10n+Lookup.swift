import Foundation

public extension L10n {
    static func activeCode(_ preferred: AppLanguage) -> String {
        if preferred != .system {
            return preferred.rawValue
        }
        let supportedCodes = AppLanguage.allCases.map(\.rawValue)
        for preference in Locale.preferredLanguages {
            let lower = preference.lowercased()
            if let match = supportedCodes.first(where: { lower.hasPrefix($0.lowercased()) }) {
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
