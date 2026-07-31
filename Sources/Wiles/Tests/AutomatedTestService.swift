import Foundation

@MainActor
public final class AutomatedTestService {
    public static func runAllTests() async {
        print("\n=======================================================")
        print("🧪 RUNNING WILES COMPREHENSIVE AUTOMATED TEST SUITE")
        print("=======================================================")
        
        TestReporter.reset()
        
        NavigationTests.run()
        ListColumnTests.run()
        await UISearchTests.run()
        UITests.run()
        LocalizationTests.run()
        FileSystemTests.run()
        ArchiveTests.run()
        BatchRenameTests.run()
        await FileShredderTests.run()
        SymlinkTests.run()
        await UndoRedoTests.run()
        await HttpServerTests.run()
        await AutoOrganizationTests.run()
        NewFileTemplateTests.run()
        await DiskSpaceVisualizerTests.run()
        ImageConverterTests.run()
        NetworkDiscoveryTests.run()
        
        let passed = TestReporter.passed
        let failed = TestReporter.failed
        
        print("=======================================================")
        print("🏁 COMPREHENSIVE SUITE COMPLETE: \(passed) Passed, \(failed) Failed")
        print("=======================================================\n")
        
        exit(failed == 0 ? 0 : 1)
    }
}
