import SwiftUI

/// Last night's heart rate, bed to wake, as one line that draws itself in. The lowest point is marked:
/// a heart that settles low is a body that rested.
struct LoopOvernightHeartCard: View {
    let points: [(ts: Int, bpm: Double)]
    let bed: Int
    let wake: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    private var low: (ts: Int, bpm: Double)? { points.min { $0.bpm < $1.bpm } }
    private var range: (lo: Double, hi: Double) {
        let lo = (points.map(\.bpm).min() ?? 40) - 4
        let hi = (points.map(\.bpm).max() ?? 90) + 4
        return (lo, max(hi, lo + 10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Heart rate overnight")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            if let low {
                Text("Lowest \(Int(low.bpm.rounded())) bpm at \(LoopFormat.clock(Date(timeIntervalSince1970: TimeInterval(low.ts)))).")
                    .font(LoopFont.body)
                    .foregroundStyle(LoopColor.text)
            }

            VStack(spacing: LoopSpace.xs) {
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    let r = range
                    let x: (Int) -> CGFloat = { CGFloat($0 - bed) / CGFloat(max(wake - bed, 1)) * w }
                    let y: (Double) -> CGFloat = { h - CGFloat(($0 - r.lo) / (r.hi - r.lo)) * h }
                    ZStack(alignment: .topLeading) {
                        line(x: x, y: y)
                            .trim(from: 0, to: drawn)
                            .stroke(LoopColor.signal, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        if let low {
                            Circle()
                                .fill(LoopColor.text)
                                .frame(width: 8, height: 8)
                                .position(x: x(low.ts), y: y(low.bpm))
                                .opacity(drawn >= 1 ? 1 : 0)
                        }
                    }
                }
                .frame(height: 96)
                Rectangle().fill(LoopColor.line).frame(height: 1)
                HStack {
                    Text(LoopFormat.clock(Date(timeIntervalSince1970: TimeInterval(bed))))
                    Spacer()
                    Text(LoopFormat.clock(Date(timeIntervalSince1970: TimeInterval(wake))))
                }
                .font(LoopFont.meta)
                .foregroundStyle(LoopColor.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibility)

            Text("A heart that settles low overnight means your body rested.")
                .font(LoopFont.explainer)
                .foregroundStyle(LoopColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.signal))
        .loopOnSeen(threshold: 0.4) {
            guard drawn == 0 else { return }
            if reduceMotion { drawn = 1 } else { withAnimation(.easeInOut(duration: 1.4)) { drawn = 1 } }
        }
    }

    private func line(x: (Int) -> CGFloat, y: (Double) -> CGFloat) -> Path {
        var p = Path()
        // A gap of more than 20 minutes (strap off, or nothing recorded) breaks the line rather than
        // drawing a straight bridge across time with no readings.
        var last: Int?
        for pt in points {
            let point = CGPoint(x: x(pt.ts), y: y(pt.bpm))
            if let l = last, pt.ts - l <= 20 * 60 { p.addLine(to: point) } else { p.move(to: point) }
            last = pt.ts
        }
        return p
    }

    private var accessibility: String {
        guard let low else { return "No heart rate recorded overnight." }
        let hi = points.map(\.bpm).max().map { Int($0.rounded()) } ?? 0
        return "Heart rate overnight, from \(hi) down to a low of \(Int(low.bpm.rounded())) beats per minute at \(LoopFormat.clock(Date(timeIntervalSince1970: TimeInterval(low.ts))))."
    }
}
