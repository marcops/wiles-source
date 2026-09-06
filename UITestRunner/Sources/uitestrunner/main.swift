import Foundation

func parseAppPath() -> String {
    let arguments = CommandLine.arguments
    if let index = arguments.firstIndex(of: "--app"), index + 1 < arguments.count {
        return arguments[index + 1]
    }
    return ".build/uitest/Wiles.app"
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
do {
    try process.launch()
} catch {
    workspace.cleanup()
    fail("\(error)")
}

print("Wiles launched (pid \(process.pid)) — bundle: \(appPath)")
Thread.sleep(forTimeInterval: 2.0)

let reporter = Reporter()
let driver = WilesDriver(process: process, workspace: workspace, reporter: reporter)

do {
    try driver.mainWindow()
} catch {
    process.terminate()
    workspace.cleanup()
    fail("\(error)")
}

Walkthrough(driver: driver).run()

process.terminate()
workspace.cleanup()
reporter.printSummary()
exit(reporter.hasFailures ? 1 : 0)
