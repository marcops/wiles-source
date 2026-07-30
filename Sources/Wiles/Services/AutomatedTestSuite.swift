import Foundation

@MainActor
public final class AutomatedTestSuite {
    public static func runAllTests() async {
        print("\n==========================================")
        print("🧪 RUNNING WILES AUTOMATED FEATURE SUITE")
        print("==========================================")
        
        var passed = 0
        var failed = 0
        
        func report(_ name: String, result: Bool, detail: String = "") {
            if result {
                passed += 1
                print("✅ [PASS] \(name)")
            } else {
                failed += 1
                print("❌ [FAIL] \(name) \(detail)")
            }
        }
        
        // 1. AppState & Navigation Tests
        do {
            let appState = AppState()
            let initial = appState.currentURL
            let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            
            appState.navigateTo(desktop)
            let navPassed = appState.currentURL.standardizedFileURL == desktop.standardizedFileURL
            report("Navigation: navigateTo(Desktop)", result: navPassed)
            
            appState.goBack()
            let backPassed = appState.currentURL.standardizedFileURL == initial.standardizedFileURL
            report("Navigation: goBack()", result: backPassed)
            
            appState.addFavorite(desktop)
            let favPassed = appState.isFavorite(desktop)
            report("Favorites: addFavorite()", result: favPassed)
            
            appState.removeFavorite(desktop)
            let remPassed = !appState.isFavorite(desktop)
            report("Favorites: removeFavorite()", result: remPassed)
        }
        
        // 2. Localization Tests
        do {
            let enStr = L10n.string(.aboutWiles, lang: .english)
            let ptStr = L10n.string(.aboutWiles, lang: .portuguese)
            let locPassed = !enStr.isEmpty && !ptStr.isEmpty && enStr != ptStr
            report("Localization: L10n string lookup (EN/PT)", result: locPassed)
        }
        
        // 3. Local HTTP Share Server Test
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let testFile = tempDir.appendingPathComponent("test_share.txt")
            try? "Hello Wiles".write(to: testFile, atomically: true, encoding: .utf8)
            
            let server = LocalHttpServerService.shared
            server.start(sharing: tempDir)
            
            // Give server a moment to start
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            var httpSuccess = false
            if let url = URL(string: "http://localhost:8080") {
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                        let html = String(data: data, encoding: .utf8) ?? ""
                        httpSuccess = html.contains("test_share.txt")
                    }
                } catch {
                    print("HTTP Fetch Error: \(error)")
                }
            }
            server.stop()
            try? FileManager.default.removeItem(at: tempDir)
            report("Feature 24: Instant Local HTTP Share Server", result: httpSuccess)
        }
        
        // 4. Auto-Organization Rule Test
        do {
            let baseTemp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let inputDir = baseTemp.appendingPathComponent("Input")
            let targetDir = baseTemp.appendingPathComponent("Target")
            
            try? FileManager.default.createDirectory(at: inputDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            
            let samplePDF = inputDir.appendingPathComponent("document.pdf")
            try? "PDF Content".write(to: samplePDF, atomically: true, encoding: .utf8)
            
            let rule = AutoOrganizationRule(
                sourceURL: inputDir,
                destinationURL: targetDir,
                conditionType: .extensionEquals,
                conditionValue: "pdf"
            )
            let service = AutoOrganizationService.shared
            let oldRules = service.rules
            service.rules = [rule]
            
            service.processFolder(inputDir)
            
            // Allow async file move to complete
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            let movedFile = targetDir.appendingPathComponent("document.pdf")
            let autoOrgPassed = FileManager.default.fileExists(atPath: movedFile.path)
            
            service.rules = oldRules
            try? FileManager.default.removeItem(at: baseTemp)
            report("Feature 28: Folder Auto-Organization Rule Execution", result: autoOrgPassed)
        }
        
        print("==========================================")
        print("🏁 SUITE COMPLETE: \(passed) Passed, \(failed) Failed")
        print("==========================================\n")
        
        exit(failed == 0 ? 0 : 1)
    }
}
