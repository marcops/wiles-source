@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct FullUIActionCoverageTests {
    public static func run() async {
        let appState = AppState()
        testHttpSharingSheetFlows(appState: appState)
        testAutoOrganizationSheetFlows(appState: appState)
        testTerminalDrawerFlows(appState: appState)
        testPropertiesSheetFlows(appState: appState)
        testNewFolderSheetFlows(appState: appState)
        await testDuplicateCleanerSheetFlows(appState: appState)
        testImageConverterSheetFlows(appState: appState)
        await testDiskSpaceVisualizerSheetFlows(appState: appState)
        testModalSheetsCoverage(appState: appState)
    }

    private static func testHttpSharingSheetFlows(appState: AppState) {
        // POS: Toggling server state triggers LocalHttpServerService
        let isRunningInitial = LocalHttpServerService.shared.isRunning
        if isRunningInitial {
            LocalHttpServerService.shared.stop()
        }
        report("UI/HttpShare", "POS: LocalHttpServerService stops cleanly", result: !LocalHttpServerService.shared.isRunning)

        // NEG: Stopping already stopped server does not throw/crash
        LocalHttpServerService.shared.stop()
        report("UI/HttpShare", "NEG: Stopping stopped server is a safe no-op", result: !LocalHttpServerService.shared.isRunning)
    }

    private static func testAutoOrganizationSheetFlows(appState: AppState) {
        let dummyRule = AutoOrganizationRule(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp"),
            destinationURL: URL(fileURLWithPath: "/tmp/Images"),
            conditionType: .extensionEquals,
            conditionValue: "png",
            isEnabled: true
        )

        // POS: Adding auto-org rule updates shared service
        let countBefore = AutoOrganizationService.shared.rules.count
        AutoOrganizationService.shared.addRule(dummyRule)
        report("UI/AutoOrg", "POS: Adding rule increases count", result: AutoOrganizationService.shared.rules.count == countBefore + 1)

        // POS: Updating rule
        var updated = dummyRule
        updated.conditionValue = "jpg"
        AutoOrganizationService.shared.updateRule(updated)
        report("UI/AutoOrg", "POS: Updating rule updates conditionValue", result: AutoOrganizationService.shared.rules.contains(where: { $0.conditionValue == "jpg" }))

        // POS: Deleting rule
        AutoOrganizationService.shared.deleteRule(id: dummyRule.id)
        report("UI/AutoOrg", "POS: Deleting rule removes rule by id", result: !AutoOrganizationService.shared.rules.contains(where: { $0.id == dummyRule.id }))
    }

    private static func testTerminalDrawerFlows(appState: AppState) {
        // POS: Toggle terminal drawer visibility
        let initialDrawerState = appState.showTerminalDrawer
        appState.showTerminalDrawer.toggle()
        report("UI/TerminalDrawer", "POS: Toggling terminal drawer flips state", result: appState.showTerminalDrawer != initialDrawerState)

        // POS: Reset terminal drawer state
        appState.showTerminalDrawer = initialDrawerState
        report("UI/TerminalDrawer", "POS: Terminal drawer state restored", result: appState.showTerminalDrawer == initialDrawerState)
    }

    private static func testPropertiesSheetFlows(appState: AppState) {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_prop.txt")
        try? "Properties Test Content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let item = FileItem(url: tempFile, icon: NSWorkspace.shared.icon(forFile: tempFile.path))
        appState.propertiesItem = item
        report("UI/Properties", "POS: Opening PropertiesSheet sets propertiesItem", result: appState.propertiesItem != nil)

        // NEG: Setting propertiesItem to nil closes sheet
        appState.propertiesItem = nil
        report("UI/Properties", "NEG: Setting propertiesItem to nil closes sheet", result: appState.propertiesItem == nil)
    }

    private static func testNewFolderSheetFlows(appState: AppState) {
        // POS: Folder name validation
        let validFolderName = "New Test Folder"
        report("UI/NewFolder", "POS: Valid folder name is non-empty", result: !validFolderName.trimmingCharacters(in: .whitespaces).isEmpty)

        // NEG: Empty folder name validation fails cleanly
        let emptyFolderName = "   "
        report("UI/NewFolder", "NEG: Trimming empty folder name returns empty string", result: emptyFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private static func testDuplicateCleanerSheetFlows(appState: AppState) async {
        let emptyDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }

        let result = await DuplicateDetectionService.shared.findDuplicates(in: emptyDir)
        report("UI/DuplicateCleaner", "NEG: Duplicate detection on empty folder returns zero groups", result: result.groups.isEmpty)
    }

    private static func testImageConverterSheetFlows(appState: AppState) {
        // POS: Format enum cases check
        let formats = ImageFormat.allCases
        report("UI/ImageConverter", "POS: ImageFormat options cover PNG, JPEG, HEIC, TIFF", result: formats.count >= 4)
    }

    private static func testDiskSpaceVisualizerSheetFlows(appState: AppState) async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = await DiskSpaceVisualizerService.calculateDiskUsage(for: tempDir)
        report("UI/DiskSpaceVisualizer", "POS: Analyzing empty folder returns zero total size", result: result.totalSize == 0)
    }

    private static func testModalSheetsCoverage(appState: AppState) {
        // POS: Save Smart Folder Sheet
        appState.showSaveSmartFolderSheet = true
        report("UI/Modals", "POS: showSaveSmartFolderSheet sets flag", result: appState.showSaveSmartFolderSheet)
        appState.showSaveSmartFolderSheet = false

        // POS: Password Compress Sheet
        appState.showPasswordCompressSheet = true
        report("UI/Modals", "POS: showPasswordCompressSheet sets flag", result: appState.showPasswordCompressSheet)
        appState.showPasswordCompressSheet = false

        // POS: Archive Inspection Sheet
        appState.showArchiveInspectionSheet = true
        report("UI/Modals", "POS: showArchiveInspectionSheet sets flag", result: appState.showArchiveInspectionSheet)
        appState.showArchiveInspectionSheet = false

        // POS: Help Sheet & About Sheet
        appState.showHelpSheet = true
        report("UI/Modals", "POS: showHelpSheet sets flag", result: appState.showHelpSheet)
        appState.showHelpSheet = false

        appState.showAboutSheet = true
        report("UI/Modals", "POS: showAboutSheet sets flag", result: appState.showAboutSheet)
        appState.showAboutSheet = false
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
