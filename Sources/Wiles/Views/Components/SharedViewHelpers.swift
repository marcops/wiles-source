import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
func scrollToTopAnimated(_ proxy: ScrollViewProxy) {
    // Deferred a tick: called right as a new row is inserted, so the list's layout hasn't
    // settled yet — scrolling in the same update cycle computes the wrong target offset.
    Task { @MainActor in
        withAnimation(MotionTokens.mediumEase) {
            proxy.scrollTo("top", anchor: .top)
        }
    }
}
