import SwiftUI

public enum MotionTokens {
    public static let snappySpring: Animation = .spring(response: 0.28, dampingFraction: 0.85)
    public static let expandSpring: Animation = .spring(response: 0.28, dampingFraction: 0.75)
    public static let gentleSpring: Animation = .spring(response: 0.55, dampingFraction: 0.82)
    public static let quickEase: Animation = .easeInOut(duration: 0.15)
    public static let mediumEase: Animation = .easeInOut(duration: 0.2)
    public static let smoothEase: Animation = .easeInOut(duration: 0.25)
}
