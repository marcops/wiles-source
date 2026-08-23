import Foundation

/// Centralized GitBeacon (crash/error → GitHub Issues) configuration. See the
/// error_handler design notes and git-beacon-mac's README for how the
/// library itself works.
public enum CrashReportingConstants {
    public static let githubOwner = "marcops"
    public static let githubRepo = "wiles"

    /// Fine-grained GitHub Personal Access Token, scoped to `githubRepo` only,
    /// with `Issues: Read and write` and nothing else. Read from the `WILES_GITHUB_TOKEN`
    /// environment variable (set it in your local shell profile or Xcode scheme) rather than
    /// hardcoded in source — until it's set, GitBeacon still captures and stores reports locally,
    /// it just can't deliver them.
    public static let githubToken = ProcessInfo.processInfo.environment["WILES_GITHUB_TOKEN"] ?? ""
}
