import Foundation
import GitBeacon

/// Loads an HTML (or other markup) template from `Resources/` and substitutes `{{PLACEHOLDER}}`
/// tokens with caller-supplied values. Keeps markup authoring out of Swift source — see rule 36 in
/// `.agents/AGENTS.md` — while any genuinely dynamic fragment (e.g. a generated list of rows) is
/// still assembled by the caller and passed in as a single replacement value.
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
        for (key, value) in replacements {
            template = template.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return template
    }
}
