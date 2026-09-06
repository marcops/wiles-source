import ApplicationServices
import Foundation

/// Process-wide Accessibility trust gate. An external AXUIElement client can only read/drive
/// another app once the *responsible* process (the terminal or IDE this runner is launched from)
/// is enabled in System Settings ▸ Privacy & Security ▸ Accessibility.
enum Accessibility {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the one-time system prompt if not yet trusted.
    @discardableResult
    static func prompt() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static let instructions = """
    Accessibility permission is required.

    The runner drives Wiles.app through the macOS Accessibility API. Grant it once:

      1. Open  System Settings ▸ Privacy & Security ▸ Accessibility
      2. Enable the app you launched this script from (Terminal, iTerm, VS Code, …).
         If it is already listed, toggle it off and on again.
      3. Re-run  scripts/run_ui_test.sh

    (A system prompt was also requested — approving it does the same thing.)
    """
}
