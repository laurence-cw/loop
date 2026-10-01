import SwiftUI

// Loop's words. The brand book's voice lives here so every screen says things the same way:
// answer first, a word beside every number, short sentences, UK English, never blame.

/// The three recovery states. Recovery is the only thing in Loop that changes colour.
enum RecoveryBand: Equatable {
    case charged, steady, low

    init(score: Int) {
        switch score {
        case 67...: self = .charged
        case 34...66: self = .steady
        default: self = .low
        }
    }

    var word: String {
        switch self {
        case .charged: return "Charged"
        case .steady: return "Steady"
        case .low: return "Low"
        }
    }

    var colour: Color {
        switch self {
        case .charged: return LoopColor.charged
        case .steady: return LoopColor.steady
        case .low: return LoopColor.low
        }
    }

    /// What today means, in one line.
    var line: String {
        switch self {
        case .charged: return "Fully charged. Good day to go hard."
        case .steady: return "Half charged. Normal day, don't overdo it."
        case .low: return "Running low. Take it easy and get to bed early."
        }
    }
}

/// Great / Good / OK / Low, used for Sleep and Effort scores on the 0-100 scale.
enum ScoreWord {
    static func word(for score: Int) -> String {
        switch score {
        case 85...: return "Great"
        case 67...84: return "Good"
        case 34...66: return "OK"
        default: return "Low"
        }
    }
}

enum LoopFormat {
    /// "9h 12m", never "9.2 hours".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// "13,277".
    static func steps(_ steps: Int) -> String {
        steps.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_GB")))
    }

    /// "7:42am", the way the status pill says it.
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f.string(from: date)
    }

    /// "Morning, Sam." / "Evening." (no name yet).
    static func greeting(name: String?, at date: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let part: String
        switch hour {
        case 4..<12: part = "Morning"
        case 12..<18: part = "Afternoon"
        default: part = "Evening"
        }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "\(part)." : "\(part), \(trimmed)."
    }
}
