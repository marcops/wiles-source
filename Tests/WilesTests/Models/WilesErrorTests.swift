import Foundation
@testable import Wiles

@MainActor
public struct WilesErrorTests {
    public static func run() {
        testErrorDescriptionsIncludeContext()
        testEquatableBehavior()
        testEveryCaseHasNonEmptyDescription()
        testLocalizedMessageSubstitutesPath()
        testLocalizedMessageSubstitutesReason()
        testLocalizedMessageForParameterlessCasesHasNoSubstitution()
        testLocalizedPartialFailureMessagesAreLocalizedAndSubstituted()
    }

    /// The partial-failure summaries (batch rename / shred / paste) and the symlink self-target
    /// guard now go through `.localized(key:arguments:)`, so they render in the app language with
    /// positional tokens filled in — not a hardcoded English string.
    private static func testLocalizedPartialFailureMessagesAreLocalizedAndSubstituted() {
        let rename = WilesError.localized(key: .batchRenamePartialFailure, arguments: ["2", "5", "a.txt: nope"])
        let english = rename.localizedMessage(lang: .english)
        let portuguese = rename.localizedMessage(lang: .portuguese)
        report(
            "Model/WilesError",
            "POS: batchRenamePartialFailure fills {0}/{1}/{2} and differs by language",
            result: english.contains("2") && english.contains("5") && english.contains("a.txt: nope") && english != portuguese)

        let paste = WilesError.localized(key: .pastePartialFailure, arguments: ["3", "7"]).localizedMessage(lang: .english)
        report("Model/WilesError", "POS: pastePartialFailure substitutes both counts", result: paste.contains("3") && paste.contains("7"))

        let move = WilesError.localized(key: .movePartialFailure, arguments: ["1", "4"]).localizedMessage(lang: .english)
        report("Model/WilesError", "POS: movePartialFailure substitutes both counts", result: move.contains("1") && move.contains("4"))

        let pdf = WilesError.localized(key: .pdfMergePartialFailure, arguments: ["2"]).localizedMessage(lang: .english)
        report("Model/WilesError", "POS: pdfMergePartialFailure substitutes the skipped count", result: pdf.contains("2"))

        let collide = WilesError.localized(key: .batchRenameWouldCollide, arguments: ["a.txt, b.txt"]).localizedMessage(lang: .english)
        report("Model/WilesError", "POS: batchRenameWouldCollide substitutes the colliding names", result: collide.contains("a.txt, b.txt"))

        let badPattern = WilesError.localized(key: .batchRenameInvalidPattern, arguments: ["[unclosed"]).localizedMessage(lang: .english)
        report("Model/WilesError", "POS: batchRenameInvalidPattern substitutes the offending pattern", result: badPattern.contains("[unclosed"))

        let symlink = WilesError.localized(key: .symlinkCannotReplaceOwnTarget, arguments: [])
        report(
            "Model/WilesError",
            "POS: symlinkCannotReplaceOwnTarget is a non-empty localized message that changes with language",
            result: !symlink.localizedMessage(lang: .english).isEmpty
                && symlink.localizedMessage(lang: .english) != symlink.localizedMessage(lang: .japanese))
    }

    /// Covers `localizedMessage(lang:)`'s multi-case-pattern branch (permissionDenied/diskFull/
    /// fileInUse/itemNotFound all substitute their associated `path`).
    private static func testLocalizedMessageSubstitutesPath() {
        let path = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("locked.txt").path
        let cases: [WilesError] = [.permissionDenied(path: path), .diskFull(path: path), .fileInUse(path: path), .itemNotFound(path: path)]
        let allContainPath = cases.allSatisfy { $0.localizedMessage(lang: .english).contains(path) }
        report(
            "Model/WilesError",
            "POS: localizedMessage substitutes the associated path for permissionDenied/diskFull/fileInUse/itemNotFound",
            result: allContainPath)
    }

    /// Covers `localizedMessage(lang:)`'s `.operationFailed(reason:)` branch.
    private static func testLocalizedMessageSubstitutesReason() {
        let message = WilesError.operationFailed(reason: "disk unmounted").localizedMessage(lang: .english)
        report("Model/WilesError", "POS: localizedMessage substitutes the reason for operationFailed", result: message.contains("disk unmounted"))
    }

    /// Covers `localizedMessage(lang:)`'s `.invalidZipPassword`/`.itemAlreadyInDestination` branch,
    /// which returns the localized format string as-is with no substitution.
    private static func testLocalizedMessageForParameterlessCasesHasNoSubstitution() {
        let zipMessage = WilesError.invalidZipPassword.localizedMessage(lang: .english)
        let destinationMessage = WilesError.itemAlreadyInDestination.localizedMessage(lang: .english)
        let notRedoableMessage = WilesError.fileCreationNotRedoable.localizedMessage(lang: .english)
        report(
            "Model/WilesError",
            "POS: localizedMessage for parameterless cases returns a non-empty message with no substitution performed",
            result: !zipMessage.isEmpty && !destinationMessage.isEmpty && !notRedoableMessage.isEmpty)
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
        report(
            "Model/WilesError",
            "POS: operationFailed includes the given reason",
            result: (operationFailed.errorDescription ?? "").contains("network unreachable"))

        report(
            "Model/WilesError",
            "POS: invalidZipPassword has a non-empty description",
            result: !(WilesError.invalidZipPassword.errorDescription ?? "").isEmpty)
        report(
            "Model/WilesError",
            "POS: itemAlreadyInDestination has a non-empty description",
            result: !(WilesError.itemAlreadyInDestination.errorDescription ?? "").isEmpty)
        report(
            "Model/WilesError",
            "POS: fileCreationNotRedoable has a non-empty description",
            result: !(WilesError.fileCreationNotRedoable.errorDescription ?? "").isEmpty)
    }

    private static func testEquatableBehavior() {
        report(
            "Model/WilesError",
            "NEG: two different error cases are not equal",
            result: WilesError.diskFull(path: "/x") != WilesError.permissionDenied(path: "/x"))
        report(
            "Model/WilesError",
            "POS: same case with same associated value is equal",
            result: WilesError.diskFull(path: "/x") == WilesError.diskFull(path: "/x"))
        report(
            "Model/WilesError",
            "NEG: same case with different associated values is not equal",
            result: WilesError.itemNotFound(path: "/a") != WilesError.itemNotFound(path: "/b"))
        report(
            "Model/WilesError",
            "POS: parameterless cases compare equal to themselves",
            result: WilesError.invalidZipPassword == WilesError.invalidZipPassword
                && WilesError.itemAlreadyInDestination == WilesError.itemAlreadyInDestination
                && WilesError.fileCreationNotRedoable == WilesError.fileCreationNotRedoable)
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
            .itemAlreadyInDestination,
            .fileCreationNotRedoable
        ]
        let allNonEmpty = allCases.allSatisfy { !($0.errorDescription ?? "").isEmpty }
        report("Model/WilesError", "POS: every WilesError case produces a non-empty errorDescription", result: allNonEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
