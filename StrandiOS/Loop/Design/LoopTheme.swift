import SwiftUI

// Loop's design layer. Every colour, size and duration a Loop screen uses comes from here,
// taken from the Loop brand book. Kept separate from StrandDesign so Noop's own screens,
// and upstream changes to them, are untouched.

enum LoopColor {
    /// App background.
    static let night = Color(loopHex: 0x07070A)
    /// Cards.
    static let surface = Color(loopHex: 0x121217)
    /// Dividers and empty arc/chart tracks.
    static let line = Color(loopHex: 0x24242C)
    /// Primary text and numbers.
    static let text = Color(loopHex: 0xF2F2F5)
    /// Labels and secondary text.
    static let muted = Color(loopHex: 0x9A9AA6)

    /// Sleep. Always this colour.
    static let signal = Color(loopHex: 0x4A63FF)
    /// Sleep stage tints, all from the Signal family: light reads clearly against Surface,
    /// dream is the palest, deep is Signal itself. Separated by gaps in the stages bar.
    static let stageLight = Color(loopHex: 0x8A96E8)
    static let stageDeep = signal
    static let stageDream = Color(loopHex: 0xC7CEFF)
    /// Activity. Always this colour.
    static let pulse = Color(loopHex: 0xE0379A)
    /// Recovery, good day.
    static let charged = Color(loopHex: 0x2EC4A6)
    /// Recovery, middling day.
    static let steady = Color(loopHex: 0xF2A93B)
    /// Recovery, low day.
    static let low = Color(loopHex: 0xFF6A55)
    /// In-between moments: onboarding, still learning, breathing. One element per screen at most.
    static let glow = Color(loopHex: 0x7B45F0)
}

enum LoopSpace {
    static let xs: CGFloat = 8
    static let s: CGFloat = 16
    static let m: CGFloat = 24
    static let l: CGFloat = 32
    static let xl: CGFloat = 48
    /// Screen edge inset.
    static let edge: CGFloat = 20
    /// Inside a card.
    static let cardPadding: CGFloat = 20
}

enum LoopShape {
    static let cardRadius: CGFloat = 24
    static let arcStroke: CGFloat = 10
}

enum LoopGlow {
    /// Glow opacity band from the brand book: noticeable only on a second look.
    static let soft: Double = 0.15
    static let strong: Double = 0.25
}

enum LoopMotion {
    /// Rings and arcs fill once on open.
    static let fill = Animation.easeOut(duration: 0.8)
    /// A chart bar growing in: quick, settling with the slightest give, never a bounce.
    static let build = Animation.spring(duration: 0.7, bounce: 0.12)
    /// Recovery colour change: a cross-fade, never a flash.
    static let colourFade = Animation.easeInOut(duration: 0.6)
    /// One slow orb breath.
    static let breathPeriod: Double = 4
    /// Scale reached at the top of a breath (1.5%).
    static let breathScale: CGFloat = 1.015
}

/// Type: SF Pro Expanded at light and regular weights for numbers and headings, SF Pro for words.
/// The owner chose this lighter cut over the brand book's original Bold/Semibold (2026-10-01).
/// Text-style based fonts follow Dynamic Type; the hero and orb word sizes are scaled with
/// @ScaledMetric where they are drawn (see LoopRing).
enum LoopFont {
    /// Big numbers (hero score, section headline numbers): Expanded Light, monospaced digits.
    static func number(size: CGFloat) -> Font {
        .system(size: size, weight: .light).width(.expanded).monospacedDigit()
    }
    /// The Recovery word under the score: Expanded Regular.
    static func word(size: CGFloat) -> Font {
        .system(size: size, weight: .regular).width(.expanded)
    }
    static let headlineNumber = number(size: 40)
    /// The small title in the navigation bar once the page title has scrolled away: Expanded Regular.
    static let inlineTitle = Font.system(.body, weight: .regular).width(.expanded)
    /// Screen title: Expanded Light.
    static let title = Font.system(.title, weight: .light).width(.expanded)
    /// The one sentence: Regular.
    static let sentence = Font.system(.title3, weight: .regular)
    /// Body: 17pt Regular.
    static let body = Font.system(.body)
    /// Row and arc-foot values: 17pt (body) Expanded Regular, monospaced digits. Body, not title3, so
    /// "Charged 84" fits one line on a 390pt-wide iPhone (13 / 16e) at the default text size.
    static let rowValue = Font.system(.body, weight: .regular).width(.expanded).monospacedDigit()
    /// Row titles ("Recovery"): body Regular.
    static let rowTitle = Font.system(.body, weight: .regular)
    /// Meta: second facts (a number under its bar, "Your normal 52–59", steps), units, the pill.
    static let meta = Font.system(.footnote, weight: .medium).monospacedDigit()
    /// Explainers: the one-line "what this means" under a measure, and honest-state lines.
    static let explainer = Font.system(.footnote, weight: .regular)
}

private extension Color {
    init(loopHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
