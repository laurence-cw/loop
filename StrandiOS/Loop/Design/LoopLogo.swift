import SwiftUI

/// Loop's mark, "Recharge": an open ring running from Sleep blue round into Activity pink, nearly
/// closing, with a Charged dot in the gap. The same geometry as the app icon (a 100-unit box: ring
/// radius 30, stroke 8, dot 12 at (76, 27)).
struct LoopMark: View {
    var size: CGFloat = 32

    /// Where the ring's two ends sit, in degrees clockwise from 3 o'clock.
    private static let pinkEnd = -20.3
    private static let blueEnd = 298.3

    var body: some View {
        ZStack {
            ArcShape(start: Self.pinkEnd, end: Self.blueEnd)
                .stroke(
                    AngularGradient(colors: [LoopColor.pulse, LoopColor.signal], center: .center,
                                    startAngle: .degrees(Self.pinkEnd), endAngle: .degrees(Self.blueEnd)),
                    style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                )
                .frame(width: size * 0.6, height: size * 0.6)
            Circle()
                .fill(LoopColor.charged)
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: size * 0.26, y: size * -0.23)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The mark beside the lowercase wordmark, as it sits at the top of Home.
struct LoopLogo: View {
    @ScaledMetric(relativeTo: .title3) private var markSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 2) {
            LoopMark(size: markSize)
            Text("loop")
                .font(.system(.title3, weight: .light).width(.expanded))
                .tracking(1.2)
                .foregroundStyle(LoopColor.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loop")
        .accessibilityAddTraits(.isHeader)
    }
}
