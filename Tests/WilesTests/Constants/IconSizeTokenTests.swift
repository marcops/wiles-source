import XCTest
@testable import Wiles

final class IconSizeTokenTests: XCTestCase {
    func testRenderResolutionIs512() {
        XCTAssertEqual(IconSizeToken.renderResolution, 512)
    }

    func testLoadedFileItemIconIsSizedToRenderResolution() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString + ".txt")
        try Data("x".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let item = FileItem.load(url: url)
        XCTAssertEqual(item.icon.size.width, IconSizeToken.renderResolution)
        XCTAssertEqual(item.icon.size.height, IconSizeToken.renderResolution)
    }
}
