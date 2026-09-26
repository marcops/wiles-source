import Foundation

/// Centralized GitBeacon (crash/error → GitHub Issues) configuration. See the
/// error_handler design notes and git-beacon-mac's README for how the
/// library itself works.
public enum CrashReportingConstants {
    public static let githubOwner = "marcops"
    public static let githubRepo = "wiles"

    // TODO: revoked by GitHub — generate a new fine-grained PAT (Issues: Read and write on githubRepo only) and fill this back in.
    public static let githubToken = ""
}
