import CoreGraphics
import Foundation

/// `--screenshots` mode: stages each FEATURES.md feature in a photogenic state and captures the
/// Wiles window in both Light and Dark appearance, writing `<slug>-light.png` / `<slug>-dark.png`
/// into `wiles-public/docs/screenshots/features/`. Language is already English (the walkthrough's
/// first step runs here too via `prepareEnglish`).
struct Screenshots {
    let driver: WilesDriver
    let outputDir: URL
    /// When set, only the shot with this slug is captured — for refreshing one feature's pair.
    var onlySlug: String?

    var workspace: TempWorkspace { driver.workspace }
    private static let windowFrame = CGRect(x: 90, y: 70, width: 1180, height: 720)

    struct Shot {
        let slug: String
        let stage: () -> Void
        let cleanup: () -> Void
    }

    func run() {
        _ = try? driver.mainWindow()
        driver.process.activate()
        Timing.pause(Timing.settle)
        driver.navigateToWorkspace()

        let selected = onlySlug.map { slug in shots().filter { $0.slug == slug } } ?? shots()
        for mode in ["light", "dark"] {
            print("\n=== \(mode.uppercased()) pass ===")
            setAppearance(mode == "dark" ? "Dark" : "Light")
            resizeWindow()
            for shot in selected {
                capture(shot, mode: mode)
            }
        }
        setAppearance("System")
        print("\nScreenshots written to \(outputDir.path)")
    }

    // MARK: - Capture

    private func capture(_ shot: Shot, mode: String) {
        driver.dismissSheet()
        driver.closeAnyMenu()
        driver.navigateToWorkspace()
        Timing.pause(Timing.brief)

        shot.stage()
        Timing.pause(Timing.animation)

        guard let window = try? driver.mainWindow() else {
            print("  ✗ \(shot.slug)-\(mode): no window")
            shot.cleanup()
            return
        }
        let file = outputDir.appendingPathComponent("\(shot.slug)-\(mode).png")
        let ok = ScreenCapture.capture(region: window.frame, to: file)
        print("  \(ok ? "✓" : "✗") \(file.lastPathComponent)")

        shot.cleanup()
        Timing.pause(Timing.brief)
    }

    // MARK: - Appearance / window

    private func setAppearance(_ option: String) {
        guard driver.openSettings(tab: "Appearance") else { return }
        driver.selectThemeOption(option)
        Timing.pause(Timing.animation)
        driver.dismissSheet()
        Timing.pause(Timing.animation)
    }

    private func resizeWindow() {
        if let window = try? driver.mainWindow() {
            window.setFrame(Self.windowFrame)
            Timing.pause(Timing.settle)
        }
    }
}
