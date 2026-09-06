import Foundation

enum RunnerError: Error, CustomStringConvertible {
    case accessibilityNotTrusted
    case appBundleMissing(String)
    case launchTimedOut
    case mainWindowNeverAppeared

    var description: String {
        switch self {
        case .accessibilityNotTrusted:
            return Accessibility.instructions
        case let .appBundleMissing(path):
            return "Wiles.app not found at \(path) — build it first (scripts/run_ui_test.sh does this)."
        case .launchTimedOut:
            return "Wiles.app did not finish launching within 30s."
        case .mainWindowNeverAppeared:
            return "Wiles launched but its main window never became visible to the Accessibility API."
        }
    }
}
