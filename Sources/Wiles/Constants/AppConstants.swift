import Foundation

public enum AppConstants {
    public static let githubURL = "https://github.com/marcops/wiles"
    public static let githubDisplayString = "github.com/marcops/wiles"
    
    public static var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? String()
    }
    
    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
