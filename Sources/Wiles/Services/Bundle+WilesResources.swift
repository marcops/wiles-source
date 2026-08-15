import Foundation

public extension Bundle {
    /// `Bundle.module` alone is unsafe here: its generated accessor only checks
    /// `Bundle.main.bundleURL/Wiles_Wiles.bundle` (top level) and a hardcoded absolute `.build`
    /// path, then `fatalError`s if neither resolves — it has no notion of `Contents/Resources/`,
    /// which is where `scripts/build_release.sh`/`push_and_relaunch.sh` actually place
    /// `Wiles_Wiles.bundle` in the shipped .app. Check the real packaging layout first (graceful,
    /// no crash on miss), and only fall back to `Bundle.module` for `swift test`/`swift build`
    /// runs outside any .app wrapper, where those candidates correctly don't apply.
    static let wilesResources: Bundle = {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("Wiles_Wiles.bundle"),
           let bundle = Bundle(url: resourceURL) {
            return bundle
        }
        let mainURL = Bundle.main.bundleURL.appendingPathComponent("Wiles_Wiles.bundle")
        if let bundle = Bundle(url: mainURL) {
            return bundle
        }
        #if SWIFT_PACKAGE
            if let buildPath = Bundle.main.path(forResource: "Wiles_Wiles", ofType: "bundle"),
               let bundle = Bundle(path: buildPath) {
                return bundle
            }
        #endif
        return .module
    }()
}
