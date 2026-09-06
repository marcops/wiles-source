import CoreGraphics
import Foundation

/// How a candidate element is matched during a subtree search.
struct AXMatch {
    var role: String?
    var identifier: String?
    /// Case-insensitive substring tested against every label in `searchableText`.
    var textContains: String?
    /// Case-insensitive exact match against title, identifier or accessibility description
    /// (SwiftUI renders `.accessibilityLabel` as `AXDescription` on a `Button`).
    var textEquals: String?
    var predicate: ((AXElement) -> Bool)?

    func matches(_ element: AXElement) -> Bool {
        if let role, element.role != role { return false }
        if let identifier, element.identifier != identifier { return false }
        if let textEquals {
            let wanted = textEquals.lowercased()
            let candidates = [element.title, element.identifier, element.descriptionText].map { $0.lowercased() }
            if !candidates.contains(wanted) { return false }
        }
        if let textContains, !element.searchableText.contains(where: { $0.contains(textContains.lowercased()) }) {
            return false
        }
        if let predicate, !predicate(element) { return false }
        return true
    }
}

/// Bounds a single tree walk by total nodes visited — a big content list (`/Applications`) plus
/// deep SwiftUI/AX wrapper nesting can otherwise make one search touch tens of thousands of
/// elements, each an IPC round-trip, and stall the whole run.
private final class NodeBudget {
    var remaining: Int
    init(_ limit: Int) { remaining = limit }
    func take() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        return true
    }
}

extension AXElement {
    static let defaultSearchDepth = 40
    static let defaultNodeBudget = 40000

    func firstDescendant(where match: AXMatch, maxDepth: Int = AXElement.defaultSearchDepth) -> AXElement? {
        firstDescendant(where: match, maxDepth: maxDepth, budget: NodeBudget(Self.defaultNodeBudget))
    }

    private func firstDescendant(where match: AXMatch, maxDepth: Int, budget: NodeBudget) -> AXElement? {
        if maxDepth <= 0 { return nil }
        for child in children {
            guard budget.take() else { return nil }
            if match.matches(child) { return child }
            if let found = child.firstDescendant(where: match, maxDepth: maxDepth - 1, budget: budget) {
                return found
            }
        }
        return nil
    }

    func allDescendants(where match: AXMatch, maxDepth: Int = AXElement.defaultSearchDepth) -> [AXElement] {
        var result: [AXElement] = []
        collectDescendants(where: match, maxDepth: maxDepth, budget: NodeBudget(Self.defaultNodeBudget), into: &result)
        return result
    }

    private func collectDescendants(
        where match: AXMatch, maxDepth: Int, budget: NodeBudget, into result: inout [AXElement]) {
        guard maxDepth > 0 else { return }
        for child in children {
            guard budget.take() else { return }
            if match.matches(child) { result.append(child) }
            child.collectDescendants(where: match, maxDepth: maxDepth - 1, budget: budget, into: &result)
        }
    }

    /// Polls `firstDescendant` until it resolves or the deadline passes.
    func waitForDescendant(
        where match: AXMatch,
        timeout: TimeInterval,
        maxDepth: Int = AXElement.defaultSearchDepth,
        pollInterval: TimeInterval = Timing.poll) -> AXElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if let found = firstDescendant(where: match, maxDepth: maxDepth) { return found }
            if Date() >= deadline { return nil }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }

    func waitUntilGone(where match: AXMatch, timeout: TimeInterval, pollInterval: TimeInterval = Timing.poll) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if firstDescendant(where: match) == nil { return true }
            Thread.sleep(forTimeInterval: pollInterval)
        } while Date() < deadline
        return firstDescendant(where: match) == nil
    }
}
