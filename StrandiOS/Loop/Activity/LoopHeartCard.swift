import SwiftUI
import WhoopStore

/// Heart rate, live and through today. The number up top is the strap's live reading (Noop's smoothed
/// `bpm`, the one every Noop screen shows), with a heart beating at that rate. Under it, today from
/// midnight to now in 5-minute steps, with the live reading riding on the end of the line.
///
/// The strap only streams live heart rate when asked, and the full stream costs battery, so this card
/// asks while it's on screen and lets go when it leaves or the app goes to the background. Noop
/// ref-counts the request (`startRealtimeHR`/`stopRealtimeHR`), so it never switches off a stream
/// another screen still wants.
struct LoopHeartCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @EnvironmentObject private var repo: Repository
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var buckets: [HRBucket] = []
    @State private var dayStart = Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970)
    @State private var loaded = false
    @State private var drawn: CGFloat = 0
    /// Whether this card currently holds a realtime request, so every start is balanced by one stop.
    @State private var holdingStream = false
    @State private var onScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Heart rate")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)

            liveRow

            if loaded {
                if points.isEmpty {
                    Text("Nothing recorded yet today.")
                        .font(LoopFont.body)
                        .foregroundStyle(LoopColor.muted)
                } else {
                    if let rangeLine {
                        Text(rangeLine)
                            .font(LoopFont.body)
                            .foregroundStyle(LoopColor.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    chart
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.pulse))
        .onAppear { onScreen = true; holdStream(scenePhase == .active) }
        .onDisappear { onScreen = false; holdStream(false) }
        .onChange(of: scenePhase) { _, phase in holdStream(onScreen && phase == .active) }
        // Today's line, re-read every minute while the card is up. Bucketed in the store, so a whole
        // day never loads the raw once-a-second readings.
        .task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    // MARK: Live

    /// The live reading, while the strap is connected and sending; nil otherwise.
    private var liveBpm: Int? {
        #if DEBUG
        if Self.previewing { return 74 }
        #endif
        guard live.connected, let b = model.bpm, (30...220).contains(b) else { return nil }
        return b
    }

    private var liveRow: some View {
        HStack(alignment: .center, spacing: LoopSpace.s) {
            LoopBeatingHeart(bpm: liveBpm)
                .frame(width: 44, height: 44)
            if let b = liveBpm {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(b)")
                        .font(LoopFont.headlineNumber)
                        .foregroundStyle(LoopColor.text)
                        .contentTransition(.numericText(value: Double(b)))
                        .animation(reduceMotion ? nil : .snappy, value: b)
                    Text("bpm").font(LoopFont.meta).foregroundStyle(LoopColor.muted)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(live.connected ? "Waiting for a reading" : "Not live right now")
                        .font(LoopFont.rowTitle)
                        .foregroundStyle(LoopColor.text)
                    Text(live.connected ? "Your strap is connected. A few seconds." : "Live heart rate shows when your strap is connected.")
                        .font(LoopFont.explainer)
                        .foregroundStyle(LoopColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if liveBpm != nil {
                LoopLiveBadge()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(liveBpm.map { "Live heart rate, \($0) beats per minute" } ?? "Live heart rate not available")
    }

    // MARK: Today

    /// Today's 5-minute means, with the live reading added at now so the line reaches the present.
    private var points: [(ts: Int, bpm: Double)] {
        var p = buckets.filter { (30...220).contains($0.bpm) }.map { (ts: $0.ts + 150, bpm: $0.bpm) }
        if let b = liveBpm { p.append((Int(Date().timeIntervalSince1970), Double(b))) }
        return p
    }

    /// Today's low and high. Taken from the readings themselves (a bucket's own min and max), not from
    /// the 5-minute means the line draws, so a short sprint counts; buckets with a weak optical signal
    /// are left out so a loose strap can't set the high.
    private var extremes: (low: Double, high: Double, highAt: Int)? {
        let good = buckets.filter { $0.conf >= 0.8 && (30...220).contains($0.minBpm) && (30...220).contains($0.maxBpm) }
        guard let lo = good.map(\.minBpm).min(), let top = good.max(by: { $0.maxBpm < $1.maxBpm }) else { return nil }
        return (lo, top.maxBpm, top.ts)
    }

    private var rangeLine: String? {
        guard let e = extremes else { return nil }
        let at = LoopFormat.clock(Date(timeIntervalSince1970: TimeInterval(e.highAt)))
        return "Today, low \(Int(e.low.rounded())) and high \(Int(e.high.rounded())) at \(at)."
    }

    private var chart: some View {
        let pts = points
        let now = max(Int(Date().timeIntervalSince1970), (pts.last?.ts ?? dayStart) + 60)
        let lo = (pts.map(\.bpm).min() ?? 50) - 6
        let hi = max((pts.map(\.bpm).max() ?? 120) + 6, lo + 20)
        return VStack(spacing: LoopSpace.xs) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let x: (Int) -> CGFloat = { CGFloat($0 - dayStart) / CGFloat(max(now - dayStart, 1)) * w }
                let y: (Double) -> CGFloat = { h - CGFloat(($0 - lo) / (hi - lo)) * h }
                ZStack(alignment: .topLeading) {
                    area(pts, x: x, y: y, floor: h)
                        .fill(LinearGradient(colors: [LoopColor.pulse.opacity(0.28), LoopColor.pulse.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(Double(drawn))
                    line(pts, x: x, y: y)
                        .trim(from: 0, to: drawn)
                        .stroke(LoopColor.pulse, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    if let last = pts.last {
                        LoopNowDot(live: liveBpm != nil)
                            .id(liveBpm != nil)
                            .position(x: x(last.ts), y: y(last.bpm))
                            .opacity(drawn >= 1 ? 1 : 0)
                    }
                }
            }
            .frame(height: 112)
            Rectangle().fill(LoopColor.line).frame(height: 1)
            HStack {
                Text("12am")
                Spacer()
                Text("Now")
            }
            .font(LoopFont.meta)
            .foregroundStyle(LoopColor.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rangeLine.map { "Heart rate through today. \($0)" } ?? "Heart rate through today.")
        .loopOnSeen(threshold: 0.4) {
            guard drawn == 0 else { return }
            if reduceMotion { drawn = 1 } else { withAnimation(.easeInOut(duration: 1.4)) { drawn = 1 } }
        }
    }

    /// A gap of more than 20 minutes (strap off, phone away) breaks the line rather than bridging it.
    private func line(_ pts: [(ts: Int, bpm: Double)], x: (Int) -> CGFloat, y: (Double) -> CGFloat) -> Path {
        var p = Path()
        var last: Int?
        for pt in pts {
            let point = CGPoint(x: x(pt.ts), y: y(pt.bpm))
            if let l = last, pt.ts - l <= 20 * 60 { p.addLine(to: point) } else { p.move(to: point) }
            last = pt.ts
        }
        return p
    }

    /// The soft fill under each unbroken stretch of the line.
    private func area(_ pts: [(ts: Int, bpm: Double)], x: (Int) -> CGFloat, y: (Double) -> CGFloat, floor: CGFloat) -> Path {
        var p = Path()
        var run: [CGPoint] = []
        func close() {
            guard let first = run.first, let end = run.last, run.count > 1 else { run = []; return }
            p.move(to: CGPoint(x: first.x, y: floor))
            run.forEach { p.addLine(to: $0) }
            p.addLine(to: CGPoint(x: end.x, y: floor))
            p.closeSubpath()
            run = []
        }
        var last: Int?
        for pt in pts {
            if let l = last, pt.ts - l > 20 * 60 { close() }
            run.append(CGPoint(x: x(pt.ts), y: y(pt.bpm)))
            last = pt.ts
        }
        close()
        return p
    }

    // MARK: Plumbing

    private func holdStream(_ want: Bool) {
        #if DEBUG
        if Self.previewing { return }
        #endif
        guard want != holdingStream else { return }
        holdingStream = want
        if want { model.startRealtimeHR() } else { model.stopRealtimeHR() }
    }

    private func load() async {
        let start = Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970)
        let now = Int(Date().timeIntervalSince1970)
        var read = await repo.hrBuckets(from: start, to: now, bucketSeconds: 300)
        #if DEBUG
        if Self.previewing { read = Self.previewBuckets(from: start, to: now) }
        #endif
        dayStart = start
        buckets = read
        if !loaded { withAnimation(.easeOut(duration: 0.3)) { loaded = true } }
    }

    #if DEBUG
    /// DEBUG-only `--loop-preview-heart-live`: a live 74 bpm and a made-up school day, for screenshots.
    static var previewing: Bool { CommandLine.arguments.contains("--loop-preview-heart-live") }

    static func previewBuckets(from: Int, to: Int) -> [HRBucket] {
        stride(from: from, to: to - 300, by: 300).compactMap { ts in
            let h = Double(ts - from) / 3600
            // Phone-away gap at school, mid-morning.
            if h > 10.2 && h < 11.0 { return nil }
            var bpm = h < 7 ? 54 + 4 * sin(h * 2) : 72 + 8 * sin(h * 1.7)
            if h > 12.3 && h < 13.0 { bpm = 150 + 15 * sin(h * 20) }   // football at lunch
            if h > 15.5 && h < 15.9 { bpm = 112 }                      // walk home
            return HRBucket(ts: ts, bpm: bpm, minBpm: bpm - 6, maxBpm: bpm + (bpm > 140 ? 18 : 8))
        }
    }
    #endif
}

/// A heart that beats at the live rate: a quick swell and settle once per beat, like a pulse under a
/// fingertip. Still and muted when there's no live reading, and still under Reduce Motion.
struct LoopBeatingHeart: View {
    let bpm: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let bpm, !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let period = 60 / Double(bpm)
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                // Two quick bumps, the lub and the dub, then rest.
                let beat = exp(-pow((phase - 0.08) * 14, 2)) + 0.55 * exp(-pow((phase - 0.30) * 14, 2))
                heart(colour: LoopColor.pulse)
                    .scaleEffect(1 + 0.16 * beat)
                    .shadow(color: LoopColor.pulse.opacity(0.35 + 0.4 * beat), radius: 6 + 8 * beat)
            }
        } else {
            heart(colour: bpm == nil ? LoopColor.muted : LoopColor.pulse)
        }
    }

    private func heart(colour: Color) -> some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 30))
            .foregroundStyle(colour)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// "Live", with a dot that breathes so it reads as on.
struct LoopLiveBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(LoopColor.pulse)
                .frame(width: 7, height: 7)
                .opacity(on ? 1 : 0.35)
            Text("Live")
                .font(LoopFont.meta)
                .foregroundStyle(LoopColor.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(LoopColor.pulse.opacity(0.14)))
        .onAppear {
            guard !reduceMotion else { on = true; return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
        }
    }
}

/// The end of today's line: where you are now. A ripple spreads from it while the reading is live.
struct LoopNowDot: View {
    let live: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripple = false

    var body: some View {
        ZStack {
            if live && !reduceMotion {
                Circle()
                    .stroke(LoopColor.pulse, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .scaleEffect(ripple ? 1.4 : 0.4)
                    .opacity(ripple ? 0 : 0.8)
            }
            Circle().fill(LoopColor.pulse).frame(width: 10, height: 10)
            Circle().fill(LoopColor.text).frame(width: 4, height: 4)
        }
        .onAppear {
            guard live, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { ripple = true }
        }
    }
}
