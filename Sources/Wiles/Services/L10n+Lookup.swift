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

    static func string(_ key: Key, lang: AppLanguage) -> String {
        let code = activeCode(lang)
        if let path = resourceBundle.path(forResource: code, ofType: "lproj") ?? resourceBundle.path(forResource: code.lowercased(), ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
        }
        return resourceBundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
    }
}
