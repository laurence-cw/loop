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
                arc(from: 180 - halfSpan, fill: sleepFraction, colour: LoopColor.signal)
                // Activity: the right side, spending downward.
                arc(from: 360 - halfSpan, fill: effortFraction, colour: LoopColor.pulse)
                LoopOrb(recovery: today.recovery, diameter: d * 0.62)
            }
            .frame(width: d, height: d)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Arcs

    /// Home's arcs are heavier than the section rings: they are the screen's two brackets.
    private let stroke: CGFloat = 16

    /// The fill is always drawn and its length animates, so the arc draws in once when real data
    /// first arrives (and eases to any later value) instead of popping in at full length.
    private func arc(from start: Double, fill: Double?, colour: Color) -> some View {
        let f = min(max(fill ?? 0, 0), 1)
        return LoopArc(span: halfSpan * 2, fill: f, colour: colour, lineWidth: stroke)
            .rotationEffect(.degrees(start - LoopArc.origin))
            .animation(reduceMotion ? nil : LoopMotion.fill, value: f)
    }
}

/// One of Home's arcs: a faint track in its own colour, and the fill lit from deep at its root to full
/// strength at its tip, with a soft glow under it and a bright bead where it ends. Drawn from
/// `origin` and rotated into place by the caller, so the gradient never wraps past 360°.
struct LoopArc: View, Animatable {
    static let origin: Double = 90

    let span: Double
    var fill: Double
    let colour: Color
    let lineWidth: CGFloat

    var animatableData: Double {
        get { fill }
        set { fill = newValue }
    }

    var body: some View {
        let o = Self.origin
        let end = o + span * fill
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        // Starts a little before the arc so the round cap at the root sits in the deep colour too.
        let lit = AngularGradient(colors: [colour.opacity(0.45), colour.opacity(0.8), colour],
                                  center: .center, startAngle: .degrees(o - 10), endAngle: .degrees(max(end, o + 1)))
        return ZStack {
            ArcShape(start: o, end: o + span)
                .stroke(colour.opacity(0.13), style: style)
            if fill > 0.001 {
                ArcShape(start: o, end: end)
                    .stroke(colour, style: style)
                    .blur(radius: lineWidth * 0.7)
                    .opacity(0.55)
                ArcShape(start: o, end: end)
                    .stroke(lit, style: style)
                ArcBead(angle: end, size: lineWidth * 0.36)
                    .fill(Color.white.opacity(0.85))
                    .shadow(color: .white.opacity(0.6), radius: 3)
            }
        }
        .padding(lineWidth / 2)
    }
}

/// A small dot on the arc's circle at `angle`: the bright tip of a Home arc.
struct ArcBead: Shape {
    var angle: Double
    let size: CGFloat

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let a = angle * .pi / 180
        let c = CGPoint(x: rect.midX + r * cos(a), y: rect.midY + r * sin(a))
        return Path(ellipseIn: CGRect(x: c.x - size / 2, y: c.y - size / 2, width: size, height: size))
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
