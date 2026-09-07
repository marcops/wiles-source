import XCTest
@testable import Wiles

/// Wires every existing hand-rolled test suite (Navigation/, FileSystem/, Services/, UI/)
/// into real XCTest test methods so `swift test`, code coverage, and Xcode's Test
/// navigator all see and run them. Each suite's own positive/negative assertions
/// are untouched — TestReporter.report now calls XCTFail on failure.
final class WilesAutomatedTests: XCTestCase {
    @MainActor
    func testNavigationTests() {
        NavigationTests.run()
    }

    @MainActor
    func testArrowKeyNavigationTests() {
        ArrowKeyNavigationTests.run()
        KeyboardShortcutDispatchTests.run()
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
        SelectionStoreTests.run()
        WindowUIStateTests.run()
        ActiveModalTests.run()
        PreferencesStoreTests.run()
        PreferencesStoreExtraTests.run()
    }

    @MainActor
    func testViewSuites() {
        ClickOutsideDetectorTests.run()
        DoubleClickZoomDetectorTests.run()
        EmptyDirectoryViewTests.run()
        FileContextMenuModifierTests.run()
        FileGridCardItemViewTests.run()
        FileItemIconViewTests.run()
        FooterBarViewTests.run()
        HeaderBarViewTests.run()
        InlineRenameFieldTests.run()
        PathBarViewTests.run()
        MainContentViewTests.run()
        OperationsPopoverViewTests.run()
        ShortcutsHUDOverlayTests.run()
        TappableRowTests.run()
    }

    @MainActor
    func testFeatureSuites() async {
        await ArchiveInspectorFeatureTests.run()
        await BatchRenameFeatureTests.run()
        await DiskSpaceVisualizerFeatureTests.run()
        await DuplicateCleanerFeatureTests.run()
        await HttpSharingFeatureTests.run()
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
    func testOpenWithTests() async throws {
        // Real LaunchServices calls crash the test process in CI (see DefaultFolderHandlerServiceTests).
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "SKIP-CI-CRASH: LaunchServices calls crash the test process in CI")
        await OpenWithTests.run()
    }

    @MainActor
    func testICloudTests() {
        ICloudTests.run()
    }

    @MainActor
    func testFilePermissionsTests() async {
        await FilePermissionsTests.run()
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
    func testExifMetadataTests() async {
        await ExifMetadataTests.run()
    }

    @MainActor
    func testArchiveInspectionTests() async {
        await ArchiveInspectionTests.run()
    }

    @MainActor
    func testArchiveTests() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "SKIP-CI-SLOW: exceeds 2s locally")
        ArchiveTests.run()
    }

    @MainActor
    func testBatchRenameTests() async {
        await BatchRenameTests.run()
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
    func testHttpServerTests() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "SKIP-CI-SLOW: exceeds 2s locally")
        await HttpServerTests.run()
    }

    @MainActor
    func testAutoOrganizationTests() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "SKIP-CI-SLOW: exceeds 2s locally")
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
    func testSyntaxHighlighterTests() async {
        await SyntaxHighlighterTests.run()
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
    func testFileMetadataTooltipServiceTests() async {
        await FileMetadataTooltipServiceTests.run()
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
        await FileSystemCombinedFilterTests.run()
        await FileSystemRecursiveSearchTests.run()
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
    func testAppStateNavigationExtraTests() async {
        await AppStateNavigationExtraTests.run()
        await AppStateDirectoryRefreshTests.run()
        ScrollerAutoHideSetterTests.run()
    }

    @MainActor
    func testAppStateNavigateToVolumesTests() async {
        await AppStateNavigateToVolumesTests.run()
    }

    @MainActor
    func testAppStateOperationsExtraTests() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "SKIP-CI-SLOW: exceeds 2s locally")
        await AppStateOperationsExtraTests.run()
        await AppStatePasteAndArchiveTests.run()
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
    func testDirectoryMonitorTests() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "SKIP-CI-SLOW: exceeds 2s locally")
        await DirectoryMonitorTests.run()
    }

    @MainActor
    func testFileItemFormattingTests() {
        FileItemFormattingTests.run()
    }

    @MainActor
    func testTagColorTests() {
        TagColorTests.run()
    }

    @MainActor
    func testSystemTagsServiceTests() {
        SystemTagsServiceTests.run()
    }
}
