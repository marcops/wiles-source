@testable import Wiles
import Foundation
import XCTest

@MainActor
public final class TestReporter {
    public static var passed = 0
    public static var failed = 0

    public static func reset() {
        passed = 0
        failed = 0
    }

    public static func report(_ category: String, _ name: String, result: Bool, detail: String = "") {
        if result {
            passed += 1
            print("✅ [PASS] [\(category)] \(name)")
        } else {
            failed += 1
            print("❌ [FAIL] [\(category)] \(name) \(detail)")
            XCTFail("[\(category)] \(name) \(detail)")
        }
    }
}
