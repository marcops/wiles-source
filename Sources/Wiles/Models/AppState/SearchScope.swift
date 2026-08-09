import SwiftUI
import Observation

public enum SearchScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case name
    case content

    public var id: String { rawValue }
}
