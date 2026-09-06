import CoreGraphics
import Foundation

/// How a candidate element is matched during a subtree search.
struct AXMatch {
    var role: String?
    var identifier: String?
    /// Case-insensitive substring tested against every label in `searchableText`.
    var textContains: String?
    /// Case-insensitive exact match against title or identifier.
    var textEquals: String?
    var predicate: ((AXElement) -> Bool)?

    func matches(_ element: AXElement) -> Bool {
        if let role, element.role != role { return false }
        if let identifier, element.identifier != identifier { return false }
        if let textEquals {
            let wanted = textEquals.lowercased()
            let hit = element.title.lowercased() == wanted || element.identifier.lowercased() == wanted
            if !hit { return false }
        }
        if let textContains, !element.searchableText.contains(where: { $0.contains(textContains.lowercased()) }) {
            return false
        }
        if let predicate, !predicate(element) { return false }
        return true
    }
}

extension AXElement {
    /// Depth-first search of this element's subtree. `maxDepth` guards against the odd cyclic /
    /// pathologically deep AX tree some AppKit views expose.
    func firstDescendant(where match: AXMatch, maxDepth: Int = 40) -> AXElement? {
        if maxDepth <= 0 { return nil }
        for child in children {
            if match.matches(child) { return child }
            if let found = child.firstDescendant(where: match, maxDepth: maxDepth - 1) { return found }
        }
        return nil
    }

    func allDescendants(where match: AXMatch, maxDepth: Int = 40) -> [AXElement] {
        guard maxDepth > 0 else { return [] }
        var result: [AXElement] = []
        for child in children {
            if match.matches(child) { result.append(child) }
            result.append(contentsOf: child.allDescendants(where: match, maxDepth: maxDepth - 1))
        }
        return result
    }

    /// Polls `firstDescendant` until it resolves or the deadline passes.
    func waitForDescendant(
        where match: AXMatch,
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.25) -> AXElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let found = firstDescendant(where: match) { return found }
            Thread.sleep(forTimeInterval: pollInterval)
        } while Date() < deadline
        return firstDescendant(where: match)
    }

    func waitUntilGone(where match: AXMatch, timeout: TimeInterval, pollInterval: TimeInterval = 0.25) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if firstDescendant(where: match) == nil { return true }
            Thread.sleep(forTimeInterval: pollInterval)
        } while Date() < deadline
        return firstDescendant(where: match) == nil
    }
}
