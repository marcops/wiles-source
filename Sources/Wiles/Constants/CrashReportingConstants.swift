import Foundation

/// Centralized GitBeacon (crash/error → GitHub Issues) configuration. See the
/// error_handler design notes and git-beacon-mac's README for how the
/// library itself works.
public enum CrashReportingConstants {
    public static let githubOwner = "marcops"
    public static let githubRepo = "wiles"

    /// GitBeacon still sends this as a bearer header, but wiles-report-worker (see baseURL below)
    /// ignores it and injects the real GitHub token server-side — nothing secret ships in the binary.
    public static let githubToken = "unused-see-wiles-report-worker"

    /// Proxies every GitHub Issues call through wiles-report-worker instead of api.github.com
    /// directly, so no live GitHub credential is embedded in the shipped app.
    public static let githubBaseURL = URL(string: "https://report.wilesfile.com")!
}
