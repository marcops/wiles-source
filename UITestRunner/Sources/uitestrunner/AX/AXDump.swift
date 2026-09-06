import Foundation

/// Prints an indented snapshot of an element's subtree — role, subrole, identifier, title, value.
/// Diagnostic only (`run_ui_test.sh --dump`); never part of a walkthrough run.
enum AXDump {
    static func tree(_ element: AXElement, maxDepth: Int = 18, indent: Int = 0) {
        guard maxDepth > 0 else { return }
        let pad = String(repeating: "  ", count: indent)
        var parts = ["\(pad)\(element.role)"]
        if !element.subrole.isEmpty { parts.append("<\(element.subrole)>") }
        if !element.identifier.isEmpty { parts.append("#\(element.identifier)") }
        if !element.title.isEmpty { parts.append("“\(element.title.prefix(60))”") }
        let description = element.descriptionText
        if !description.isEmpty { parts.append("desc=“\(description.prefix(50))”") }
        if let value = element.stringValue, !value.isEmpty { parts.append("val=“\(value.prefix(40))”") }
        print(parts.joined(separator: " "))
        for child in element.children {
            tree(child, maxDepth: maxDepth - 1, indent: indent + 1)
        }
    }
}
