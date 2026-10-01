import SwiftUI

/// The loop, drawn literally: Sleep's arc fills up the left side, Activity's arc spends down the
/// right, and the Recovery orb sits in the middle glowing the colour of what's left.
struct LoopRing: View {
    let today: LoopToday
    /// Sleep filled, 0...1 (hours slept against hours needed). Nil draws only the empty track.
    let sleepFraction: Double?
    /// Activity spent, 0...1 (effort out of 100). Nil draws only the empty track.
    let effortFraction: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far each arc runs either side of its middle (9 o'clock for Sleep, 3 o'clock for Activity),
    /// in degrees. Short of a half each, so the top and bottom stay open and the two arcs read as
    /// brackets around the orb rather than a closed ring.
    private let halfSpan: Double = 52

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                // SwiftUI angles run clockwise from 3 o'clock.
                // Sleep: the left side, filling upward.
                arc(from: 180 - halfSpan, to: 180 + halfSpan, fill: sleepFraction, colour: LoopColor.signal)
                // Activity: the right side, spending downward.
                arc(from: 360 - halfSpan, to: 360 + halfSpan, fill: effortFraction, colour: LoopColor.pulse)
                LoopOrb(recovery: today.recovery, diameter: d * 0.62)
            }
            .frame(width: d, height: d)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Arcs

    /// The fill is always drawn and its length animates, so the arc draws in once when real data
    /// first arrives (and eases to any later value) instead of popping in at full length.
    private func arc(from start: Double, to end: Double, fill: Double?, colour: Color) -> some View {
        let f = min(max(fill ?? 0, 0), 1)
        return ZStack {
            ArcShape(start: start, end: end)
                .stroke(LoopColor.line, style: StrokeStyle(lineWidth: LoopShape.arcStroke, lineCap: .round))
            ArcShape(start: start, end: start + (end - start) * f)
                .stroke(colour, style: StrokeStyle(lineWidth: LoopShape.arcStroke, lineCap: .round))
                .opacity(f > 0.001 ? 1 : 0)
        }
        .padding(LoopShape.arcStroke / 2)
        .animation(reduceMotion ? nil : LoopMotion.fill, value: f)
    }
}

/// The Recovery orb: a Surface disc lit from behind in the colour of what's left. It breathes slowly.
struct LoopOrb: View {
    let recovery: LoopToday.Recovery
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 56
    @ScaledMetric(relativeTo: .title2) private var wordSize: CGFloat = 18

    var body: some View {
        let tint = orbTint
        return ZStack {
            // The glow: behind the orb only, soft enough to notice on a second look.
            Circle()
                .fill(tint.opacity(LoopGlow.strong))
                .frame(width: diameter * 1.18, height: diameter * 1.18)
                .blur(radius: diameter * 0.16)

            Circle()
                .fill(LoopColor.surface)
                .overlay(
                    Circle().fill(
                        RadialGradient(colors: [tint.opacity(LoopGlow.strong), tint.opacity(0)],
                                       center: .center, startRadius: 0, endRadius: diameter * 0.55)
                    )
                )
                .overlay(Circle().strokeBorder(tint.opacity(LoopGlow.strong), lineWidth: 1))
                .frame(width: diameter, height: diameter)

            if case .learning(let nights, let of) = recovery {
                learningRing(nights: nights, of: of, diameter: diameter)
            }

            orbContent
                .frame(width: diameter * 0.84)
        }
        .scaleEffect(breathing && !reduceMotion ? LoopMotion.breathScale : 1)
        .animation(LoopMotion.colourFade, value: recovery)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: LoopMotion.breathPeriod / 2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private var orbTint: Color {
        switch recovery {
        case .scored(let s), .carried(let s): return RecoveryBand(score: s).colour
        case .learning: return LoopColor.glow
        case .noData: return LoopColor.line
        }
    }

    @ViewBuilder
    private var orbContent: some View {
        switch recovery {
        case .scored(let s), .carried(let s):
            let band = RecoveryBand(score: s)
            VStack(spacing: 0) {
                LoopCountUp(value: Double(s), format: { "\(Int($0.rounded()))" })
                    .font(LoopFont.number(size: heroSize))
                    .foregroundStyle(LoopColor.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(band.word)
                    .font(LoopFont.word(size: wordSize))
                    .foregroundStyle(band.colour)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if case .carried = recovery {
                    Text("From last night")
                        .font(.footnote)
                        .foregroundStyle(LoopColor.muted)
                        .padding(.top, 4)
                }
            }
        case .learning(let nights, let of):
            VStack(spacing: 2) {
                Text("\(nights)/\(of)")
                    .font(LoopFont.number(size: 32))
                    .foregroundStyle(LoopColor.text)
                    .minimumScaleFactor(0.6)
                Text("nights")
                    .font(LoopFont.word(size: wordSize))
                    .foregroundStyle(LoopColor.muted)
            }
        case .noData:
            Text("No score")
                .font(LoopFont.word(size: wordSize))
                .foregroundStyle(LoopColor.muted)
        }
    }

    private func learningRing(nights: Int, of: Int, diameter: CGFloat) -> some View {
        let f = of > 0 ? min(Double(nights) / Double(of), 1) : 0
        return ZStack {
            Circle().stroke(LoopColor.line, lineWidth: 4)
            Circle()
                .trim(from: 0, to: f)
                .stroke(LoopColor.glow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : LoopMotion.fill, value: f)
        }
        .frame(width: diameter - 20, height: diameter - 20)
    }
}

/// An arc of a circle between two angles (degrees, clockwise from 3 o'clock).
struct ArcShape: Shape {
    var start: Double
    var end: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, end) }
        set { start = newValue.first; end = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2,
                 startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        return p
    }
}
