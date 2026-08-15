import AppKit

public struct HapticService: Sendable {
    public static let shared = Self()

    private init() { }

    public func play(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        Task { @MainActor in
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
        }
    }
}
