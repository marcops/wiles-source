import ApplicationServices
import CoreGraphics
import Foundation

/// AX action name strings. The SDK's `kAX…Action` symbols are not all surfaced to Swift, so the
/// literals are pinned here once.
enum AXAction {
    static let press = "AXPress"
    static let showMenu = "AXShowMenu"
    static let pick = "AXPick"
    static let confirm = "AXConfirm"
    static let cancel = "AXCancel"
}

/// Thin wrapper over an `AXUIElement`, exposing just the attribute reads / actions / tree
/// traversal the walkthrough needs. All calls are synchronous AX API calls against the target
/// process; a per-element messaging timeout keeps a hung app from blocking the runner forever.
final class AXElement {
    let ref: AXUIElement

    init(_ ref: AXUIElement) {
        self.ref = ref
        AXUIElementSetMessagingTimeout(ref, 12)
    }

    static func application(pid: pid_t) -> AXElement {
        AXElement(AXUIElementCreateApplication(pid))
    }

    // MARK: - Attributes

    private func rawValue(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(ref, attribute as CFString, &value)
        return result == .success ? value : nil
    }

    var role: String { string(kAXRoleAttribute) ?? "" }
    var subrole: String { string(kAXSubroleAttribute) ?? "" }
    var title: String { string(kAXTitleAttribute) ?? "" }
    var identifier: String { string(kAXIdentifierAttribute) ?? "" }
    var roleDescription: String { string(kAXRoleDescriptionAttribute) ?? "" }
    var help: String { string(kAXHelpAttribute) ?? "" }
    var descriptionText: String { string(kAXDescriptionAttribute) ?? "" }
    var stringValue: String? { string(kAXValueAttribute) }
    var isEnabled: Bool { bool(kAXEnabledAttribute) ?? true }
    var isSelected: Bool { bool(kAXSelectedAttribute) ?? false }

    /// Every label an AX search might match on, lowercased once.
    var searchableText: [String] {
        [title, identifier, roleDescription, help, descriptionText, stringValue ?? ""]
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
    }

    func string(_ attribute: String) -> String? {
        rawValue(attribute) as? String
    }

    func bool(_ attribute: String) -> Bool? {
        (rawValue(attribute) as? NSNumber)?.boolValue
    }

    func element(_ attribute: String) -> AXElement? {
        guard let value = rawValue(attribute) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        // swiftlint:disable:next force_cast
        return AXElement(value as! AXUIElement)
    }

    func elements(_ attribute: String) -> [AXElement] {
        guard let array = rawValue(attribute) as? [AXUIElement] else { return [] }
        return array.map(AXElement.init)
    }

    var children: [AXElement] { elements(kAXChildrenAttribute) }
    var windows: [AXElement] { elements(kAXWindowsAttribute) }
    var menuBar: AXElement? { element(kAXMenuBarAttribute) }

    var frame: CGRect {
        guard
            let positionValue = rawValue(kAXPositionAttribute),
            let sizeValue = rawValue(kAXSizeAttribute)
        else { return .zero }
        var point = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        return CGRect(origin: point, size: size)
    }

    // MARK: - Actions

    @discardableResult
    func perform(_ action: String) -> Bool {
        AXUIElementPerformAction(ref, action as CFString) == .success
    }

    @discardableResult
    func press() -> Bool { perform(AXAction.press) }

    @discardableResult
    func setValue(_ value: String) -> Bool {
        AXUIElementSetAttributeValue(ref, kAXValueAttribute as CFString, value as CFTypeRef) == .success
    }

    @discardableResult
    func focus() -> Bool {
        AXUIElementSetAttributeValue(ref, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
    }

    var actionNames: [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(ref, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }
}
