import SwiftUI

/// Charts build rather than appear: each bar grows from its baseline, one after another, the first
/// time it scrolls into view. Under Reduce Motion the bars are simply there.
struct LoopBuildIn: ViewModifier {
    /// Position in the chart; each step waits a little longer, so the bars build left to right.
    let index: Int
    /// The edge the bar grows from: `.bottom` for column charts, `.top` for bedtime-to-wake bars,
    /// `.leading` for horizontal bars.
    var anchor: UnitPoint = .bottom
    /// Seconds between one bar and the next.
    var stagger: Double = 0.06

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var built = false

    private var horizontal: Bool { anchor == .leading || anchor == .trailing }

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: horizontal && !built ? 0.001 : 1,
                         y: !horizontal && !built ? 0.001 : 1,
                         anchor: anchor)
            .opacity(built ? 1 : 0)
            .loopOnSeen(threshold: 0.4) {
                guard !built else { return }
                if reduceMotion {
                    built = true
                } else {
                    withAnimation(LoopMotion.build.delay(Double(index) * stagger)) { built = true }
                }
            }
    }
}

extension View {
    func loopBuildIn(_ index: Int, from anchor: UnitPoint = .bottom, stagger: Double = 0.06) -> some View {
        modifier(LoopBuildIn(index: index, anchor: anchor, stagger: stagger))
    }
}

/// Runs once the view is scrolled into view (iOS 18 and later), or when it appears on older systems.
struct LoopOnSeen: ViewModifier {
    let threshold: Double
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: threshold) { visible in if visible { action() } }
        } else {
            content.onAppear(perform: action)
        }
    }
}

extension View {
    func loopOnSeen(threshold: Double = 0.4, perform action: @escaping () -> Void) -> some View {
        modifier(LoopOnSeen(threshold: threshold, action: action))
    }
}
