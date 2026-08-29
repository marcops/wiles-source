import Foundation

public enum AppConstants {
    public static let githubURL = "https://github.com/marcops/wiles"
    public static let githubDisplayString = "github.com/marcops/wiles"

    public static var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? String()
    }

    public static let appVersion = "0.3.15"

    public static var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// Scene identifier for the main `WindowGroup`, so `openWindow(id:)` (used by the translated
    /// "New Window" File-menu command in `WilesApp.swift`) can target it explicitly.
    public static let mainWindowID = "main"
}
