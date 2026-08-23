import Foundation

/// Centralized GitBeacon (crash/error → GitHub Issues) configuration. See the
/// error_handler design notes and git-beacon-mac's README for how the
/// library itself works.
public enum CrashReportingConstants {
    public static let githubOwner = "marcops"
    public static let githubRepo = "wiles"

    /// Fine-grained GitHub Personal Access Token, scoped to `githubRepo` only, with `Issues: Read
    /// and write` and nothing else. Deliberately hardcoded, not read from an env var/Keychain: no
    /// paid Apple Developer account means no Xcode-managed signing/provisioning to inject secrets
    /// at build time for distributed release builds, so this is the only way a shipped .app can
    /// actually deliver crash reports. Keep it hardcoded here — do not move it to an env var.
    public static let githubToken =
        "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" // swiftlint:disable:this no_hardcoded_secrets
}
