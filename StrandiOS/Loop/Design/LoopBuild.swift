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
            .loopOnSeen(threshold: 0.05) {
                guard !built else { return }
                if reduceMotion {
                    built = true
                } else {
                    withAnimation(LoopMotion.build.delay(Double(index) * stagger * 0.5)) { built = true }
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
    func loopOnSeen(threshold: Double = 0.05, perform action: @escaping () -> Void) -> some View {
        modifier(LoopOnSeen(threshold: threshold, action: action))
    }
}

/// A number that counts up to its value when it appears, and eases to any new value after. Monospaced
/// digits in the caller's font keep it from jittering as it counts. Plain under Reduce Motion.
struct LoopCountUp: View {
    let value: Double
    let format: (Double) -> String
    var duration: Double = 0.9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        LoopCountUpText(value: shown, format: format)
            .accessibilityLabel(format(value))
            .onAppear { settle() }
            .onChange(of: value) { _, _ in settle() }
    }

    private func settle() {
        if reduceMotion { shown = value; return }
        withAnimation(.easeOut(duration: duration)) { shown = value }
    }
}

/// The animatable text under `LoopCountUp`: SwiftUI interpolates `value` and redraws each frame.
private struct LoopCountUpText: View, Animatable {
    var value: Double
    let format: (Double) -> String
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View { Text(format(value)) }
}
