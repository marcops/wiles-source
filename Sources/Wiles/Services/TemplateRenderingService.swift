import Foundation
import GitBeacon

/// Loads an HTML (or other markup) template from `Resources/` and substitutes `{{PLACEHOLDER}}`
/// tokens with caller-supplied values. Keeps markup authoring out of Swift source (see
/// SWIFT_LANG_RULES.md "No Embedded Text/Templates/HTML/Markup in Swift Source") — while any
/// genuinely dynamic fragment (e.g. a generated list of rows) is still assembled by the caller
/// and passed in as a single replacement value.
public enum TemplateRenderingService {
    public static func render(resource: String, extension fileExtension: String = "html", replacements: [String: String]) -> String? {
        guard let url = Bundle.wilesResources.url(forResource: resource, withExtension: fileExtension) else {
            return nil
        }
        var template: String
        do {
            template = try String(contentsOf: url, encoding: .utf8)
        } catch {
            ErrorReporter.report(error, context: "Loading template resource \(resource).\(fileExtension)")
            return nil
        }
        return substitute(in: template, replacements: replacements)
    }

    /// Single left-to-right pass over the template: each `{{KEY}}` token is replaced with its
    /// value (unknown tokens are left literal). A value that itself contains `{{...}}` is never
    /// re-scanned, so a caller-supplied dynamic string (e.g. a filename served over the LAN) can't
    /// inject another placeholder's substitution.
    static func substitute(in template: String, replacements: [String: String]) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{(\\w+)\\}\\}") else { return template }
        let ns = template as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: template, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let key = ns.substring(with: match.range(at: 1))
            result += replacements[key] ?? ns.substring(with: match.range)
            cursor = match.range.location + match.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
