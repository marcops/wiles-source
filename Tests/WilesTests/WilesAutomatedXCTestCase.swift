import XCTest
@testable import Wiles

// Wires every existing hand-rolled test suite (Navigation/, FileSystem/, Services/, UI/)
// into real XCTest test methods so `swift test`, code coverage, and Xcode's Test
// navigator all see and run them. Each suite's own positive/negative assertions
// are untouched — TestReporter.report now calls XCTFail on failure.
final class WilesAutomatedTests: XCTestCase {
    @MainActor
    func testNavigationTests() {
        NavigationTests.run()
    }

    @MainActor
    func testArrowKeyNavigationTests() {
        ArrowKeyNavigationTests.run()
    }

    @MainActor
    func testListColumnTests() {
        ListColumnTests.run()
    }

    @MainActor
    func testUISearchTests() async {
        await UISearchTests.run()
    }

    @MainActor
    func testUITests() {
        UITests.run()
    }

    @MainActor
    func testFullUIActionCoverageTests() async {
        await FullUIActionCoverageTests.run()
    }

    @MainActor
    func testModelSuites() {
        FileItemTests.run()
        FolderNodeTests.run()
        SidebarItemTests.run()
        FileOperationTaskTests.run()
        ClipboardStateTests.run()
        DirectoryCacheEntryTests.run()
        DirectoryLoadResultTests.run()
        FileSystemStoreTests.run()
        ModalStoreTests.run()
        PreferencesStoreTests.run()
    }

    @MainActor
    func testViewSuites() {
        ClickOutsideDetectorTests.run()
        DoubleClickZoomDetectorTests.run()
        EmptyDirectoryViewTests.run()
        FileContextMenuModifierTests.run()
        FileItemIconViewTests.run()
        FooterBarViewTests.run()
        HeaderBarViewTests.run()
        PathBarViewTests.run()
        MainContentViewTests.run()
        OperationsPopoverViewTests.run()
        RenameSheetViewTests.run()
        ShortcutsHUDOverlayTests.run()
        SingleInputSheetViewTests.run()
    }

    @MainActor
    func testFeatureSuites() async {
        await ArchiveInspectorFeatureTests.run()
        BatchRenameFeatureTests.run()
        await DiskSpaceVisualizerFeatureTests.run()
        DiskSpaceVisualizerSheetViewTests.run()
        await DuplicateCleanerFeatureTests.run()
        await FileShredderFeatureTests.run()
        HttpSharingFeatureTests.run()
        ImageConverterFeatureTests.run()
        SmartFoldersFeatureTests.run()
    }

    @MainActor
    func testLocalizationTests() {
        LocalizationTests.run()
    }

    @MainActor
    func testFileSystemTests() async {
        await FileSystemTests.run()
    }

    @MainActor
    func testFileItemBulkPrefetchTests() async {
        await FileItemBulkPrefetchTests.run()
    }

    @MainActor
    func testCopyPathTests() {
        CopyPathTests.run()
    }

    @MainActor
    func testOpenWithTests() {
        OpenWithTests.run()
    }

    @MainActor
    func testICloudTests() {
        ICloudTests.run()
    }

    @MainActor
    func testFilePermissionsTests() {
        FilePermissionsTests.run()
    }

    @MainActor
    func testSmartFolderTests() {
        SmartFolderTests.run()
    }

    @MainActor
    func testPDFMergeTests() async {
        await PDFMergeTests.run()
    }

    @MainActor
    func testExifMetadataTests() {
        ExifMetadataTests.run()
    }

    @MainActor
    func testArchiveInspectionTests() async {
        await ArchiveInspectionTests.run()
    }

    @MainActor
    func testArchiveTests() {
        ArchiveTests.run()
    }

    @MainActor
    func testBatchRenameTests() {
        BatchRenameTests.run()
    }

    @MainActor
    func testFileShredderTests() async {
        await FileShredderTests.run()
    }

    @MainActor
    func testSymlinkTests() {
        SymlinkTests.run()
    }

    @MainActor
    func testUndoRedoTests() async {
        await UndoRedoTests.run()
    }

    @MainActor
    func testHttpServerTests() async {
        await HttpServerTests.run()
    }

    @MainActor
    func testAutoOrganizationTests() async {
        await AutoOrganizationTests.run()
    }

    @MainActor
    func testNewFileTemplateTests() {
        NewFileTemplateTests.run()
    }

    @MainActor
    func testDiskSpaceVisualizerTests() async {
        await DiskSpaceVisualizerTests.run()
    }

    @MainActor
    func testImageConverterTests() {
        ImageConverterTests.run()
    }

    @MainActor
    func testNetworkDiscoveryTests() {
        NetworkDiscoveryTests.run()
    }

    @MainActor
    func testPermissionTests() {
        PermissionTests.run()
    }

    @MainActor
    func testSyntaxHighlighterTests() {
        SyntaxHighlighterTests.run()
    }

    @MainActor
    func testDuplicateDetectionTests() async {
        await DuplicateDetectionTests.run()
    }

    @MainActor
    func testFileMetadataTests() async {
        await FileMetadataTests.run()
    }

    @MainActor
    func testDirectoryCacheTests() {
        DirectoryCacheTests.run()
    }

    @MainActor
    func testBackgroundOperationsTests() {
        BackgroundOperationsTests.run()
    }

    @MainActor
    func testMiscModelTests() {
        MiscModelTests.run()
    }

    @MainActor
    func testAppStateOperationsTests() {
        AppStateOperationsTests.run()
    }

    @MainActor
    func testImageConverterCoverageTests() {
        ImageConverterCoverageTests.run()
    }

    @MainActor
    func testColumnAutoFitTests() {
        ColumnAutoFitTests.run()
    }

    @MainActor
    func testLocalizationCoverageTests() {
        LocalizationCoverageTests.run()
    }

    @MainActor
    func testThumbnailServiceCoverageTests() async {
        await ThumbnailServiceCoverageTests.run()
    }

    @MainActor
    func testFileSystemSearchAndSortTests() async {
        await FileSystemSearchAndSortTests.run()
    }

    @MainActor
    func testAppStateColumnsAndSelectionTests() {
        AppStateColumnsAndSelectionTests.run()
    }

    @MainActor
    func testAppStateCoreTests() async {
        await AppStateCoreTests.run()
    }

    @MainActor
    func testAppStateNavigationExtraTests() {
        AppStateNavigationExtraTests.run()
    }

    @MainActor
    func testAppStateOperationsExtraTests() async {
        await AppStateOperationsExtraTests.run()
    }

    @MainActor
    func testAutoOrganizationRuleAndListColumnTests() {
        AutoOrganizationRuleAndListColumnTests.run()
    }

    @MainActor
    func testSmallModelEnumsTests() {
        SmallModelEnumsTests.run()
    }

    @MainActor
    func testStateAndTaskModelsTests() {
        StateAndTaskModelsTests.run()
    }

    @MainActor
    func testDirectoryMonitorTests() async {
        await DirectoryMonitorTests.run()
    }

    @MainActor
    func testFileItemFormattingTests() {
        FileItemFormattingTests.run()
    }
}
