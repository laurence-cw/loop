import SwiftUI

/// Heart-rate zones today: minutes in each of Noop's five zones, hardest first, as bars that grow in.
/// The line up top is the one number that matters for training: time spent hard or flat out.
struct LoopZonesCard: View {
    let minutes: [Double]
    let floors: [Int]
    let maxHR: Int?

    private static let names = ["Easy", "Light", "Moderate", "Hard", "Max"]

    private var peak: Double { max(minutes.max() ?? 1, 1) }
    private var hardMinutes: Int { Int((minutes.dropFirst(3).reduce(0, +)).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Heart rate zones")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            Text(summary)
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.text)
                .fixedSize(horizontal: false, vertical: true)

            if minutes.count == 5 {
                VStack(spacing: LoopSpace.s) {
                    // Hardest at the top, the way effort reads.
                    ForEach((0..<5).reversed(), id: \.self) { z in zoneRow(z) }
                }
                .padding(.top, LoopSpace.xs)
            }

            if let maxHR {
                Text("Zones come from your age: your heart's top speed is about \(maxHR) bpm.")
                    .font(LoopFont.explainer)
                    .foregroundStyle(LoopColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.pulse))
    }

    private func zoneRow(_ z: Int) -> some View {
        let m = minutes[z]
        return HStack(spacing: LoopSpace.s) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Self.names[z])
                    .font(LoopFont.rowTitle)
                    .foregroundStyle(LoopColor.text)
                if z < floors.count {
                    Text("\(floors[z])+ bpm")
                        .font(LoopFont.meta)
                        .foregroundStyle(LoopColor.muted)
                }
            }
            .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LoopColor.line).frame(height: 8)
                    Capsule()
                        .fill(LoopColor.pulse.opacity(0.35 + 0.65 * Double(z) / 4))
                        .frame(width: max(geo.size.width * CGFloat(m / peak), m > 0 ? 4 : 0), height: 8)
                        .loopBuildIn(4 - z, from: .leading, stagger: 0.08)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)
            Text(LoopFormat.duration(m * 60))
                .font(LoopFont.meta)
                .foregroundStyle(LoopColor.text)
                .frame(width: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.names[z]): \(LoopFormat.duration(m * 60))")
    }

    private var summary: String {
        guard minutes.count == 5, minutes.reduce(0, +) >= 1 else { return "No heart rate from today yet." }
        if hardMinutes >= 1 { return "\(LoopFormat.duration(Double(hardMinutes) * 60)) hard or flat out today." }
        return "All easy so far today."
    }
}

/// Calories burned: Noop's whole-day estimate from heart rate, with the week beside it.
struct LoopCaloriesCard: View {
    let today: Double?
    let week: [LoopActivity.Day]

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpace.s) {
            Text("Calories burned")
                .font(LoopFont.rowTitle)
                .foregroundStyle(LoopColor.muted)
            if let today {
                HStack(alignment: .firstTextBaseline, spacing: LoopSpace.xs) {
                    Text(LoopFormat.steps(Int(today.rounded())))
                        .font(LoopFont.headlineNumber)
                        .foregroundStyle(LoopColor.text)
                    Text("kcal so far")
                        .font(LoopFont.meta)
                        .foregroundStyle(LoopColor.muted)
                }
            } else {
                Text("Not enough of today yet.")
                    .font(LoopFont.body)
                    .foregroundStyle(LoopColor.muted)
            }
            LoopWeekBars(title: "This week", values: week.map(\.kcal),
                         maxValue: max(week.compactMap(\.kcal).max() ?? 2_500, 2_500),
                         format: { "\(LoopFormat.steps(Int($0))) kcal" })
                .padding(.top, LoopSpace.xs)
            Text("Everything your body used, from your heart rate. It counts up through the day.")
                .font(LoopFont.explainer)
                .foregroundStyle(LoopColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LoopSpace.cardPadding)
        .background(LoopCardBackground(glow: LoopColor.pulse))
    }
}
