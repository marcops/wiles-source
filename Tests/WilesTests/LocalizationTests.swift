import Foundation
import WilesCore

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
    }
}
