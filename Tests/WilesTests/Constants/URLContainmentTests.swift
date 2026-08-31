import XCTest
@testable import Wiles

/// Standalone suite for `URL.isDescendantOrSelf(of:)` — the shared component-wise path-containment
/// helper that replaced the copy-pasted `Array(pathComponents.prefix(...)) == ...` idiom.
final class URLContainmentTests: XCTestCase {
    private func url(_ path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    func testSelfIsDescendantOrSelf() {
        XCTAssertTrue(url("/Users/foo").isDescendantOrSelf(of: url("/Users/foo")))
    }

    func testNestedPathIsDescendant() {
        XCTAssertTrue(url("/Users/foo/Documents/x").isDescendantOrSelf(of: url("/Users/foo")))
    }

    func testSiblingWithSharedPrefixIsNotDescendant() {
        // The whole point: string `hasPrefix` would say `/Users/foo2` is inside `/Users/foo`.
        XCTAssertFalse(url("/Users/foo2").isDescendantOrSelf(of: url("/Users/foo")))
        XCTAssertFalse(url("/Users/foo2/x").isDescendantOrSelf(of: url("/Users/foo")))
    }

    func testAncestorIsNotDescendantOfChild() {
        XCTAssertFalse(url("/Users").isDescendantOrSelf(of: url("/Users/foo")))
    }

    func testCaseInsensitiveByDefault() {
        XCTAssertTrue(url("/Users/Foo/Bar").isDescendantOrSelf(of: url("/users/foo")))
    }

    func testCaseSensitiveWhenRequested() {
        XCTAssertFalse(url("/Users/Foo/Bar").isDescendantOrSelf(of: url("/users/foo"), caseInsensitive: false))
        XCTAssertTrue(url("/Users/Foo/Bar").isDescendantOrSelf(of: url("/Users/Foo"), caseInsensitive: false))
    }
}
