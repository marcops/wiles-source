import AppKit
import Foundation

extension PlanWalkthrough {
    /// The seeded content files shared by most edge-case/corner tests. Was declared three times,
    /// identically, as a private property in three different files — consolidated here.
    var cornerSeeded: [String] {
        [workspace.alphaFile, workspace.betaFile, workspace.midFile, workspace.imageFile,
         workspace.zipFile, workspace.pdfOne, workspace.pdfTwo]
    }

    /// Count of seeded content rows currently reporting the AX "selected" trait. Uses the same
    /// per-name `fileRow` lookup the (passing) keyboard-selection step relies on.
    func selectedRowCount() -> Int {
        cornerSeeded.filter { driver.fileRow($0, timeout: 1)?.isSelected == true }.count
    }

    /// Count of seeded content rows currently visible in the list.
    func visibleSeededCount() -> Int {
        cornerSeeded.filter { driver.find(AXMatch(textEquals: $0), timeout: 1) != nil }.count
    }

    /// The seeded files (not the folder) in on-screen order, top-to-bottom then left-to-right.
    /// SwiftUI's AX tree lists each row more than once, so de-duplicate keeping first occurrence.
    func contentFileOrder() -> [String] {
        guard let window = try? driver.mainWindow() else { return [] }
        let rows = window.allDescendants(where: AXMatch(role: "AXButton", predicate: { element in
            self.cornerSeeded.contains(element.descriptionText) || self.cornerSeeded.contains(element.title)
        }), maxDepth: 18)
        var seen = Set<String>()
        return rows
            .filter { !$0.frame.isEmpty }
            .sorted { lhs, rhs in
                lhs.frame.minY == rhs.frame.minY ? lhs.frame.minX < rhs.frame.minX : lhs.frame.minY < rhs.frame.minY
            }
            .map { $0.descriptionText.isEmpty ? $0.title : $0.descriptionText }
            .filter { seen.insert($0).inserted }
    }

    /// Width of a known file card — moves with the icon-zoom level in grid view.
    func gridWidth() -> CGFloat {
        driver.fileRow(workspace.alphaFile)?.frame.width ?? 0
    }

    /// Top-most seeded file/folder row currently in the content list (by on-screen Y).
    func firstContentRowLabel() -> String {
        let names = [
            workspace.alphaFile, workspace.betaFile, workspace.subFolder,
            workspace.imageFile, workspace.zipFile, workspace.pdfOne, workspace.pdfTwo,
        ]
        guard let scope = try? driver.mainWindow() else { return "" }
        let rows = scope.allDescendants(where: AXMatch(role: "AXButton", predicate: { element in
            names.contains(element.descriptionText) || names.contains(element.title)
        }), maxDepth: 16)
        return rows
            .filter { !$0.frame.isEmpty }
            .min { $0.frame.minY < $1.frame.minY }
            .map { $0.descriptionText.isEmpty ? $0.title : $0.descriptionText } ?? ""
    }

    func removeUntitled(prefixes: [String]) {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: workspace.root.path)) ?? []
        where prefixes.contains(where: { name.hasPrefix($0) }) {
            try? FileManager.default.removeItem(at: workspace.url(name))
        }
    }

    /// Reveals the search field (toggling the magnifier if needed) and returns it.
    func revealSearchField() -> AXElement? {
        if driver.find(AXMatch(identifier: "SearchTextField"), timeout: 1) == nil {
            _ = driver.activateSearch()
            Timing.pause(Timing.settle)
        }
        return driver.find(AXMatch(identifier: "SearchTextField"), timeout: 4)
    }

    /// Empties the search field and dismisses the search UI.
    func clearSearch(_ field: AXElement?) {
        if let field { driver.focusAndType(field, "") }
        driver.key(Keyboard.escape)
        Timing.pause(Timing.brief)
    }

    /// The "Whole Mac" search toggle — flips search between this folder and a recursive home crawl.
    func wholeMacToggle() -> AXElement? {
        (try? driver.mainWindow())?
            .firstDescendant(where: AXMatch(role: "AXButton", textContains: "whole mac"), maxDepth: 30)
    }

    /// Opens the search filter menu and clicks the first item whose text contains `fragment`.
    @discardableResult
    func pickSearchFilter(_ fragment: String) -> Bool {
        guard let button = driver.find(AXMatch(textContains: "search filters"), timeout: 3) else { return false }
        driver.tapElement(button)
        Timing.pause(Timing.settle)
        if driver.app.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: fragment), maxDepth: 16) == nil {
            _ = tapMenuItem(containing: "scope")
        }
        let picked = tapMenuItem(containing: fragment)
        driver.closeAnyMenu()
        return picked
    }

    func tapMenuItem(containing fragment: String) -> Bool {
        guard let item = driver.app.waitForDescendant(
            where: AXMatch(role: "AXMenuItem", textContains: fragment), timeout: 3, maxDepth: 16) else { return false }
        return driver.tapElement(item)
    }

    /// The footer status string, read off its "Status Bar" element (bottom static-text scrape fallback).
    func footerStatusText() -> String {
        if let element = driver.find(AXMatch(identifier: "Status Bar"), timeout: 2),
           let value = element.stringValue ?? (element.title.isEmpty ? nil : element.title) {
            return value
        }
        guard let window = try? driver.mainWindow() else { return "" }
        return window.allDescendants(where: AXMatch(role: "AXStaticText"), maxDepth: 30)
            .filter { !$0.frame.isEmpty }
            .sorted { $0.frame.minY > $1.frame.minY }
            .prefix(5)
            .compactMap { $0.stringValue ?? ($0.title.isEmpty ? nil : $0.title) }
            .joined(separator: " · ")
    }

    func fileTagNames(_ url: URL) -> [String] {
        (try? url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? []
    }

    func readPasteboardString() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    func writePasteboardString(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    /// Last path components of any file URLs currently on the general pasteboard.
    func pasteboardFileNames() -> [String] {
        let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        return urls.map { $0.lastPathComponent }
    }

    func firstPort(in text: String) -> Int? {
        guard let match = text.range(of: #"(?<![\d.])\d{4,5}(?![\d.])"#, options: .regularExpression) else {
            return nil
        }
        return Int(text[match])
    }

    func httpGet(_ urlString: String, timeout: TimeInterval = 4) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        URLSession.shared.dataTask(with: request) { data, _, _ in
            box.value = data.flatMap { String(data: $0, encoding: .utf8) }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 1)
        return box.value
    }

    private final class ResultBox: @unchecked Sendable {
        var value: String?
    }
}
