import Foundation

// Line-buffer stdout so a piped/backgrounded run shows progress instead of one dump at exit.
setvbuf(stdout, nil, _IOLBF, 0)

if let index = CommandLine.arguments.firstIndex(of: "--scale"), index + 1 < CommandLine.arguments.count,
   let scale = Double(CommandLine.arguments[index + 1]) {
    Timing.scale = scale
}
if CommandLine.arguments.contains("--fast") {
    Timing.scale = 0.45
}
if CommandLine.arguments.contains("--no-relaunch") {
    Timing.allowRelaunch = false
}
if CommandLine.arguments.contains("--slow") {
    Timing.scale = 1.0
}

func parseArgument(_ name: String, default fallback: String) -> String {
    let arguments = CommandLine.arguments
    if let index = arguments.firstIndex(of: name), index + 1 < arguments.count {
        return arguments[index + 1]
    }
    return fallback
}

func parseAppPath() -> String {
    parseArgument("--app", default: ".build/uitest/Wiles.app")
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(2)
}

let appPath = parseAppPath()

guard Accessibility.isTrusted else {
    Accessibility.prompt()
    fail(Accessibility.instructions)
}

let bundleURL = URL(fileURLWithPath: appPath)
guard FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent("Contents/Info.plist").path) else {
    fail(RunnerError.appBundleMissing(appPath).description)
}

let workspace = TempWorkspace()
do {
    try workspace.prepare()
} catch {
    fail("could not prepare temp workspace: \(error)")
}

let process = WilesProcess(bundleURL: bundleURL)
process.setInitialFolder(workspace.root)
do {
    try process.launch()
} catch {
    workspace.cleanup()
    fail("\(error)")
}

print("Wiles launched (pid \(process.pid)) — bundle: \(appPath)")
Timing.pause(Timing.launch)

let reporter = Reporter()
let driver = WilesDriver(process: process, workspace: workspace, reporter: reporter)

// A throttled machine can take a while to paint the first window; relaunch a couple of times
// before giving up.
var windowReady = false
for attempt in 0 ..< 3 {
    if (try? driver.mainWindow(timeout: 30)) != nil { windowReady = true; break }
    print("  ↻ no window after launch \(attempt + 1) — relaunching")
    try? process.relaunch()
    driver.rebindToRelaunchedApp()
    Timing.pause(Timing.launch)
}
if !windowReady {
    process.terminate()
    workspace.cleanup()
    fail("\(RunnerError.mainWindowNeverAppeared)")
}
process.activate()

if CommandLine.arguments.contains("--dump") {
    driver.navigateToWorkspace()
    Timing.pause(Timing.launch)
    if let window = try? driver.mainWindow() {
        AXDump.tree(window)
    }
    print("\n===== MENU BAR =====")
    if let menuBar = driver.app.menuBar {
        for barItem in menuBar.children where !barItem.title.isEmpty {
            barItem.press()
            Timing.pause(Timing.settle)
            AXDump.tree(barItem, maxDepth: 4)
            Keyboard.press(Keyboard.escape, pid: process.pid)
            Timing.pause(Timing.brief)
        }
    }
    process.terminate()
    workspace.cleanup()
    exit(0)
}

if CommandLine.arguments.contains("--screenshots") {
    let defaultOut = "\(NSHomeDirectory())/source/wiles-public/docs/screenshots/features"
    let outDir = URL(fileURLWithPath: parseArgument("--out", default: defaultOut))
    let onlySlug = parseArgument("--only", default: "")
    Screenshots(driver: driver, outputDir: outDir, onlySlug: onlySlug.isEmpty ? nil : onlySlug).run()
    process.terminate()
    workspace.cleanup()
    exit(0)
}

let onlyList = parseArgument("--only", default: "")
    .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

if CommandLine.arguments.contains("--all") {
    Walkthrough(driver: driver).run(only: onlyList)
    try? process.relaunch()
    driver.rebindToRelaunchedApp()
    _ = try? driver.mainWindow()
    PlanWalkthrough(driver: driver).run(only: onlyList)
} else if CommandLine.arguments.contains("--plan") {
    PlanWalkthrough(driver: driver).run(only: onlyList)
} else {
    Walkthrough(driver: driver).run(only: onlyList)
}

process.terminate()
workspace.cleanup()
reporter.printSummary()
exit(reporter.hasFailures ? 1 : 0)
