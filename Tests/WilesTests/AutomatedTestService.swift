@testable import Wiles
import Foundation

@MainActor
public final class AutomatedTestService {
    public static func runAllTests() async {
        print("\n=======================================================")
        print("🧪 RUNNING WILES COMPREHENSIVE AUTOMATED TEST SUITE")
        print("=======================================================")

        TestReporter.reset()

        await runCoreAndFileSystemTests()
        await runOrganizationAndUtilityTests()
        await runModelAndStateTests()

        let passed = TestReporter.passed
        let failed = TestReporter.failed

        print("=======================================================")
        print("🏁 COMPREHENSIVE SUITE COMPLETE: \(passed) Passed, \(failed) Failed")
        print("=======================================================\n")

        exit(failed == 0 ? 0 : 1)
    }

    private static func runCoreAndFileSystemTests() async {
        NavigationTests.run()
        ArrowKeyNavigationTests.run()
        ListColumnTests.run()
        await UISearchTests.run()
        UITests.run()
        LocalizationTests.run()
        await FileSystemTests.run()
        await FileItemBulkPrefetchTests.run()
        CopyPathTests.run()
        OpenWithTests.run()
        ICloudTests.run()
        FilePermissionsTests.run()
        SmartFolderTests.run()
        await PDFMergeTests.run()
        ExifMetadataTests.run()
        await ArchiveInspectionTests.run()
        ArchiveTests.run()
        BatchRenameTests.run()
        await FileShredderTests.run()
        SymlinkTests.run()
    }

    private static func runOrganizationAndUtilityTests() async {
        await UndoRedoTests.run()
        await HttpServerTests.run()
        await AutoOrganizationTests.run()
        NewFileTemplateTests.run()
        await DiskSpaceVisualizerTests.run()
        ImageConverterTests.run()
        NetworkDiscoveryTests.run()
        PermissionTests.run()
        SyntaxHighlighterTests.run()
        await DuplicateDetectionTests.run()
        await FileMetadataTests.run()
        await FileMetadataTooltipServiceTests.run()
        DirectoryCacheTests.run()
        BackgroundOperationsTests.run()
        MiscModelTests.run()
        AppStateOperationsTests.run()
        ImageConverterCoverageTests.run()
        ColumnAutoFitTests.run()
        LocalizationCoverageTests.run()
        await ThumbnailServiceCoverageTests.run()
    }

    private static func runModelAndStateTests() async {
        await FileSystemSearchAndSortTests.run()
        AppStateColumnsAndSelectionTests.run()
        await AppStateCoreTests.run()
        await AppStateNavigationExtraTests.run()
        await AppStateNavigateToVolumesTests.run()
        await AppStateOperationsExtraTests.run()
        AutoOrganizationRuleAndListColumnTests.run()
        SmallModelEnumsTests.run()
        StateAndTaskModelsTests.run()
        await DirectoryMonitorTests.run()
        FileItemFormattingTests.run()
        WindowUIStateTests.run()
    }
}
