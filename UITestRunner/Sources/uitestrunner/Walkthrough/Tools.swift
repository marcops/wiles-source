import Foundation

extension PlanWalkthrough {
    // MARK: - Duplicate Finder — real scan

    func featDuplicateFinderScan() {
        reporter.beginFeature("Duplicate Finder — scan surfaces an identical pair")
        // Two byte-identical files so the detector has a real group to report.
        let dupA = "dup-a-uitest.txt"
        let dupB = "dup-b-uitest.txt"
        let payload = Data("wiles duplicate finder fixture payload\n".utf8)
        try? payload.write(to: workspace.url(dupA))
        try? payload.write(to: workspace.url(dupB))
        defer {
            try? FileManager.default.removeItem(at: workspace.url(dupA))
            try? FileManager.default.removeItem(at: workspace.url(dupB))
        }
        driver.navigateToWorkspace()
        guard driver.menuPick("Tools", itemContains: "Find Duplicate Files", "Tools ▸ Find Duplicate Files") else { return }
        guard driver.waitForSheet() else {
            reporter.fail("Find Duplicate Files sheet never opened")
            return
        }
        // The scan runs on open; give it a beat, then confirm it found the pair rather than
        // landing on the empty state.
        var foundResults = false
        let deadline = Date().addingTimeInterval(15)
        repeat {
            if driver.sheet()?.firstDescendant(where: AXMatch(textContains: "reclaimable"), maxDepth: 14) != nil
                || driver.sheet()?.firstDescendant(where: AXMatch(textContains: dupB), maxDepth: 16) != nil {
                foundResults = true
                break
            }
            Timing.pause(Timing.settle)
        } while Date() < deadline
        let emptyState = driver.sheet()?.firstDescendant(where: AXMatch(textContains: "no duplicate files"), maxDepth: 14) != nil
        reporter.check(foundResults && !emptyState, "the scan reported the identical pair (results view, not the empty state)")
        reporter.check(driver.dismissSheet(), "Duplicate Finder sheet dismissed")
    }

    // MARK: - HTTP server round trip

    func featHTTPServerRoundTrip() {
        reporter.beginFeature("HTTP Sharing — start, fetch, stop")
        driver.navigateToWorkspace()
        guard driver.openContextItem(onFileRow: workspace.subFolder, containing: "share folder over wi-fi", "context ▸ Share over Wi-Fi")
        else { return }
        guard driver.waitForSheet() else {
            reporter.fail("HTTP Sharing sheet did not open")
            return
        }
        let startButton = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "start"))
        if let startButton { driver.tapElement(startButton) }
        Timing.pause(Timing.animation)
        let sheetText = (driver.sheet()?.allDescendants(where: AXMatch(role: "AXStaticText"), maxDepth: 12) ?? [])
            .compactMap { $0.stringValue ?? ($0.title.isEmpty ? nil : $0.title) }
            .joined(separator: " ")
        let port = firstPort(in: sheetText)
        if let port {
            let body = httpGet("http://127.0.0.1:\(port)/")
            reporter.check(body != nil, "the shared folder answers on port \(port)")
        } else {
            reporter.check(startButton != nil, "HTTP share sheet exposes a Start control (no port string to probe)")
        }
        if let stop = driver.sheet()?.firstDescendant(where: AXMatch(role: "AXButton", textContains: "stop")) {
            driver.tapElement(stop)
        }
        Timing.pause(Timing.settle)
        driver.dismissSheet()
    }
}

extension Walkthrough {
    // MARK: - Image Converter

    func featImageConverter() {
        reporter.beginFeature("Image Converter")
        driver.navigateToWorkspace()
        guard driver.openContextItem(
            onFileRow: workspace.imageFile,
            containing: "quick convert",
            "context ▸ Quick Convert & Resize") else { return }
        reporter.check(driver.waitForSheet(), "Image Converter sheet opened")
        reporter.check(driver.dismissSheet(), "Image Converter sheet dismissed")
    }

    // MARK: - Duplicate Finder

    func featDuplicateFinder() {
        reporter.beginFeature("Duplicate Finder")
        driver.navigateToWorkspace()
        guard driver.menuPick("Tools", itemContains: "Find Duplicate Files", "Tools ▸ Find Duplicate Files") else { return }
        reporter.check(driver.waitForSheet(), "Find Duplicate Files sheet opened")
        reporter.check(driver.dismissSheet(), "Find Duplicate Files sheet dismissed")
    }

    // MARK: - Integrated Terminal

    func featIntegratedTerminal() {
        reporter.beginFeature("Integrated Terminal")
        driver.navigateToWorkspace()
        guard driver.menuPick("View", itemContains: "Show Terminal", "View ▸ Show Terminal") else { return }
        reporter.check(
            driver.menuHasItem("View", containing: "Hide Terminal"),
            "View menu flipped to 'Hide Terminal' — the terminal drawer is showing")
        driver.menuPick("View", itemContains: "Hide Terminal", "View ▸ Hide Terminal (restore)")
    }

    // MARK: - Disk Usage Visualizer

    func featDiskUsageVisualizer() {
        reporter.beginFeature("Disk Usage Visualizer")
        driver.navigateToWorkspace()
        driver.chord("d", [.command, .shift])
        Timing.pause(Timing.animation)
        let flipped = driver.menuHasItem("View", containing: "Hide Disk Usage")
        if !flipped {
            driver.menuPick("View", itemContains: "Show Disk Usage", "View ▸ Show Disk Usage")
        }
        reporter.check(
            flipped || driver.menuHasItem("View", containing: "Hide Disk Usage"),
            "Disk Usage pane is showing (View menu offers 'Hide Disk Usage')")
        driver.menuPick("View", itemContains: "Hide Disk Usage", "View ▸ Hide Disk Usage (restore)")
    }

    // MARK: - Connect to Server

    func featConnectToServer() {
        reporter.beginFeature("Connect to Server")
        driver.navigateToWorkspace()
        guard driver.menuPick("Go", itemContains: "Connect to Server", "Go ▸ Connect to Server") else { return }
        reporter.check(driver.waitForSheet(), "Connect to Server sheet opened")
        reporter.check(driver.dismissSheet(), "Connect to Server sheet dismissed")
    }

    // MARK: - Auto-Organization Rules

    func featAutoOrganization() {
        reporter.beginFeature("Auto-Organization Rules")
        driver.navigateToWorkspace()
        guard driver.menuPick("Tools", itemContains: "Auto-Organization", "Tools ▸ Auto-Organization") else { return }
        reporter.check(driver.waitForSheet(), "Auto-Organization sheet opened")
        reporter.check(driver.dismissSheet(), "Auto-Organization sheet dismissed")
    }

    // MARK: - HTTP Sharing

    func featHTTPSharing() {
        reporter.beginFeature("HTTP Sharing")
        driver.navigateToWorkspace()
        guard driver.openContextItem(
            onFileRow: workspace.subFolder,
            containing: "share folder over wi-fi",
            "context ▸ Share Folder over Wi-Fi") else { return }
        reporter.check(driver.waitForSheet(), "HTTP Sharing sheet opened")
        reporter.check(driver.dismissSheet(), "HTTP Sharing sheet dismissed")
    }
}
