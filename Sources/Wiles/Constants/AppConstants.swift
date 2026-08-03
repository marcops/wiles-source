import Foundation

public enum AppConstants {
    public static let githubURL = "https://github.com/marcops/wiles"
    public static let githubDisplayString = "github.com/marcops/wiles"
    
    public static var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? String()
    }
    
    public static let appVersion = "0.1.3"
}
