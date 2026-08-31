import Foundation
@testable import Wiles

@MainActor
public struct LocalizationTests {
    public static func run() {
        let enStr = L10n.string(.aboutWiles, lang: .english)
        let ptStr = L10n.string(.aboutWiles, lang: .portuguese)
        let esStr = L10n.string(.aboutWiles, lang: .spanish)
        let frStr = L10n.string(.aboutWiles, lang: .french)
        let deStr = L10n.string(.aboutWiles, lang: .german)

        let posLoc = !enStr.isEmpty && !ptStr.isEmpty && !esStr.isEmpty && !frStr.isEmpty && !deStr.isEmpty
        TestReporter.report("Localization", "POS: Multi-language string resolution (EN/PT/ES/FR/DE)", result: posLoc)

        let sysStr = L10n.string(.aboutWiles, lang: .system)
        TestReporter.report("Localization", "POS/NEG: System language fallback resolution", result: !sysStr.isEmpty)

        // LU-030b: deleting a smart folder removes a saved query — it must NOT be labelled
        // "Move to Trash" (nothing is trashed).
        let deleteLabel = L10n.string(.deleteSmartFolder, lang: .english)
        let trashLabel = L10n.string(.moveToTrash, lang: .english)
        TestReporter.report(
            "Localization",
            "POS: the smart-folder delete action has its own label, distinct from 'Move to Trash' (LU-030b)",
            result: !deleteLabel.isEmpty && deleteLabel != trashLabel)
    }
}
