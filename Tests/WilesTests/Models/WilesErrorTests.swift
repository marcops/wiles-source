@testable import Wiles
import Foundation

@MainActor
public struct WilesErrorTests {
    public static func run() {
        testErrorDescriptionsIncludeContext()
        testEquatableBehavior()
        testEveryCaseHasNonEmptyDescription()
    }

    private static func testErrorDescriptionsIncludeContext() {
        let deniedPath = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("secret.txt").path
        let permissionDenied = WilesError.permissionDenied(path: deniedPath)
        report("Model/WilesError", "POS: permissionDenied includes the offending path", result: (permissionDenied.errorDescription ?? "").contains(deniedPath))

        let fullPath = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("big.bin").path
        let diskFull = WilesError.diskFull(path: fullPath)
        report("Model/WilesError", "POS: diskFull includes the offending path", result: (diskFull.errorDescription ?? "").contains(fullPath))

        let busyPath = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("busy.txt").path
        let fileInUse = WilesError.fileInUse(path: busyPath)
        report("Model/WilesError", "POS: fileInUse includes the offending path", result: (fileInUse.errorDescription ?? "").contains(busyPath))

        let missingPath = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("gone.txt").path
        let notFound = WilesError.itemNotFound(path: missingPath)
        report("Model/WilesError", "POS: itemNotFound includes the offending path", result: (notFound.errorDescription ?? "").contains(missingPath))

        let operationFailed = WilesError.operationFailed(reason: "network unreachable")
        report("Model/WilesError", "POS: operationFailed includes the given reason", result: (operationFailed.errorDescription ?? "").contains("network unreachable"))

        report("Model/WilesError", "POS: invalidZipPassword has a non-empty description", result: !(WilesError.invalidZipPassword.errorDescription ?? "").isEmpty)
        report("Model/WilesError", "POS: itemAlreadyInDestination has a non-empty description", result: !(WilesError.itemAlreadyInDestination.errorDescription ?? "").isEmpty)
    }

    private static func testEquatableBehavior() {
        report(
            "Model/WilesError",
            "NEG: two different error cases are not equal",
            result: WilesError.diskFull(path: "/x") != WilesError.permissionDenied(path: "/x")
        )
        report(
            "Model/WilesError",
            "POS: same case with same associated value is equal",
            result: WilesError.diskFull(path: "/x") == WilesError.diskFull(path: "/x")
        )
        report(
            "Model/WilesError",
            "NEG: same case with different associated values is not equal",
            result: WilesError.itemNotFound(path: "/a") != WilesError.itemNotFound(path: "/b")
        )
        report(
            "Model/WilesError",
            "POS: parameterless cases compare equal to themselves",
            result: WilesError.invalidZipPassword == WilesError.invalidZipPassword
                && WilesError.itemAlreadyInDestination == WilesError.itemAlreadyInDestination
        )
    }

    /// Exhaustively exercises every case so a future addition without a matching `report()` call
    /// here would be a silent coverage gap, not a compile-time one (the enum has no `CaseIterable`
    /// conformance to iterate automatically).
    private static func testEveryCaseHasNonEmptyDescription() {
        let allCases: [WilesError] = [
            .permissionDenied(path: "/a"),
            .diskFull(path: "/a"),
            .fileInUse(path: "/a"),
            .itemNotFound(path: "/a"),
            .operationFailed(reason: "reason"),
            .invalidZipPassword,
            .itemAlreadyInDestination
        ]
        let allNonEmpty = allCases.allSatisfy { !($0.errorDescription ?? "").isEmpty }
        report("Model/WilesError", "POS: every WilesError case produces a non-empty errorDescription", result: allNonEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
