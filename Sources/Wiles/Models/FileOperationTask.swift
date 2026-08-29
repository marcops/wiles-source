import Foundation

public struct FileOperationTask: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    /// Generic progress units (item count today, real bytes later) — not named "bytes" on purpose.
    public var unitsDone: Int64
    public var unitsTotal: Int64

    /// Derived, and clamped to `0...1` so `unitsDone > unitsTotal` can't push a bar past 100%.
    public var progress: Double {
        guard unitsTotal > 0 else { return 0 }
        return min(1, Double(unitsDone) / Double(unitsTotal))
    }

    public init(
        id: UUID = UUID(),
        title: String,
        unitsDone: Int64 = 0,
        unitsTotal: Int64 = 0) {
        self.id = id
        self.title = title
        self.unitsDone = unitsDone
        self.unitsTotal = unitsTotal
    }
}
