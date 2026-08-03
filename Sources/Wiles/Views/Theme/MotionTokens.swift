import SwiftUI

public enum MotionTokens {
    public static let snappySpring: Animation = .spring(response: 0.28, dampingFraction: 0.85)
    public static let gentleSpring: Animation = .spring(response: 0.35, dampingFraction: 0.80)
    public static let quickEase: Animation = .easeInOut(duration: 0.15)
    public static let smoothEase: Animation = .easeInOut(duration: 0.25)
}
