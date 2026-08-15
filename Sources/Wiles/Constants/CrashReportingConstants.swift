import Foundation

/// Centralized GitBeacon (crash/error → GitHub Issues) configuration. See the
/// error_handler design notes and git-beacon-mac's README for how the
/// library itself works.
public enum CrashReportingConstants {
    public static let githubOwner = "marcops"
    public static let githubRepo = "wiles"

    /// Fine-grained GitHub Personal Access Token, scoped to `githubRepo` only,
    /// with `Issues: Read and write` and nothing else. Must be filled in
    /// before crash/error reports can actually reach GitHub — until then,
    /// GitBeacon still captures and stores reports locally, it just can't
    /// deliver them.
    public static let githubToken = "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"
}
