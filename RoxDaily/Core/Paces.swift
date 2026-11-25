import Foundation

/// Pace targets derived from a current 5 km time. All values are seconds per km.
struct Paces {
    let fiveK: Double

    init(fiveKSeconds: Int) {
        fiveK = Double(max(fiveKSeconds, 14 * 60)) / 5.0
    }

    /// Conversational, zone 2.
    var easyFast: Double { fiveK * 1.25 }
    var easySlow: Double { fiveK * 1.38 }
    /// Comfortably hard, roughly one-hour race effort.
    var threshold: Double { fiveK * 1.08 }
    /// 1 km repeat pace.
    var interval: Double { fiveK * 1.0 }
    /// Short, fast repeats (400 m).
    var speed: Double { fiveK * 0.94 }
    /// Sustainable run pace between stations on race day.
    var race: Double { fiveK * 1.15 }

    var easyText: String { "\(Fmt.pace(easyFast))-\(Fmt.pace(easySlow)) /km (\(Fmt.pace(easyFast * Fmt.mile))-\(Fmt.pace(easySlow * Fmt.mile)) /mi)" }
    var thresholdText: String { Fmt.paceBoth(threshold) }
    var intervalText: String { Fmt.paceBoth(interval) }
    var speedText: String { Fmt.paceBoth(speed) }
    var raceText: String { Fmt.paceBoth(race) }

    /// Time for a rep of the given distance at a pace, e.g. "3:12".
    func rep(_ meters: Double, at pace: Double) -> String {
        Fmt.clock(Int((pace * meters / 1000).rounded()))
    }
}

enum Fmt {
    static let mile = 1.609344

    static func clock(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func pace(_ secPerKm: Double) -> String { clock(Int(secPerKm.rounded())) }

    static func paceBoth(_ secPerKm: Double) -> String {
        "\(pace(secPerKm)) /km (\(pace(secPerKm * mile)) /mi)"
    }

    static func kg(_ kg: Double) -> String {
        let lb = Int((kg * 2.20462).rounded())
        let k = kg == kg.rounded() ? String(Int(kg)) : String(format: "%.1f", kg)
        return "\(k) kg (\(lb) lb)"
    }

    static func km(_ km: Double) -> String {
        let k = km == km.rounded() ? String(Int(km)) : String(format: "%.1f", km)
        return "\(k) km (\(String(format: "%.1f", km / mile)) mi)"
    }

    /// Splits a leading amount off a workout line: "25 m sled push" becomes ("25 m", "sled push").
    static func quantity(_ item: String) -> (qty: String?, rest: String) {
        let pattern = #"^(\d+(?:[.:]\d+)?(?:-\d+)?(?: x \d+(?:\.\d+)?)?(?: (?:km|m|min|s)(?= ))?) ([A-Za-z(].*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: item, range: NSRange(item.startIndex..., in: item)),
              let q = Range(m.range(at: 1), in: item), let r = Range(m.range(at: 2), in: item) else {
            return (nil, item)
        }
        return (String(item[q]), String(item[r]))
    }
}
