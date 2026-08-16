import Observation
import SwiftUI

public enum SearchScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case name
    case content
    case both

    public var id: String {
        rawValue
    }
}
