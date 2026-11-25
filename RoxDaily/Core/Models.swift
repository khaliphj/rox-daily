import Foundation

// MARK: - Athlete profile

enum Division: String, Codable, CaseIterable, Identifiable {
    case openWomen, openMen, proWomen, proMen, doublesWomen, doublesMen, doublesMixed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .openWomen: return "Open Women"
        case .openMen: return "Open Men"
        case .proWomen: return "Pro Women"
        case .proMen: return "Pro Men"
        case .doublesWomen: return "Doubles Women"
        case .doublesMen: return "Doubles Men"
        case .doublesMixed: return "Doubles Mixed"
        }
    }
}

enum Level: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .beginner: return "First race, or training under 4 hours a week"
        case .intermediate: return "Consistent training, chasing a faster time"
        case .advanced: return "Experienced, high volume, competitive goals"
        }
    }
    /// Multiplier applied to volume (reps, distances, rounds).
    var volume: Double {
        switch self {
        case .beginner: return 0.75
        case .intermediate: return 1.0
        case .advanced: return 1.2
        }
    }
}

struct Profile: Codable, Equatable {
    var raceDate: Date
    var planStart: Date
    var division: Division = .openMen
    var level: Level = .intermediate
    var daysPerWeek: Int = 5
    /// Current 5 km time in seconds. Drives every pace target.
    var fiveKSeconds: Int = 27 * 60
    var hasSled = true
    var hasSkiErg = true
    var hasRower = true
    var hasWallBall = true
    /// Home city, used to localise the news feeds.
    var city = "Atlanta"
}

// MARK: - Plan

enum Phase: String, Codable, CaseIterable {
    case base, build, specific, taper, raceWeek

    var title: String {
        switch self {
        case .base: return "Base"
        case .build: return "Build"
        case .specific: return "Race Specific"
        case .taper: return "Taper"
        case .raceWeek: return "Race Week"
        }
    }

    var focus: String {
        switch self {
        case .base:
            return "Build the aerobic engine and learn every station. Most running is easy; strength work is heavier with full rest."
        case .build:
            return "Raise threshold and start running on tired legs. Intervals get longer, station work gets denser."
        case .specific:
            return "Train the race itself: race weights, race order, race pace. Simulations tell you how to pace the day."
        case .taper:
            return "Cut volume, keep some intensity. You are absorbing the work, not adding fitness."
        case .raceWeek:
            return "Stay loose, stay sharp, sleep. Nothing this week makes you fitter, it only makes you fresher."
        }
    }
}

enum SessionKind: String, Codable {
    case easyRun, longRun, intervals, tempo, strength, stations, compromised, simulation, recovery, rest, race

    var title: String {
        switch self {
        case .easyRun: return "Easy Run"
        case .longRun: return "Long Run"
        case .intervals: return "Run Intervals"
        case .tempo: return "Threshold"
        case .strength: return "Strength"
        case .stations: return "Station Work"
        case .compromised: return "Compromised Running"
        case .simulation: return "Race Simulation"
        case .recovery: return "Recovery"
        case .rest: return "Rest Day"
        case .race: return "Race Day"
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .easyRun, .longRun: return "figure.run"
        case .intervals: return "bolt.fill"
        case .tempo: return "speedometer"
        case .strength: return "dumbbell.fill"
        case .stations: return "figure.strengthtraining.functional"
        case .compromised: return "flame.fill"
        case .simulation: return "flag.checkered"
        case .recovery: return "figure.cooldown"
        case .rest: return "bed.double.fill"
        case .race: return "trophy.fill"
        }
    }

    var isTraining: Bool { self != .rest }
}

struct WorkoutBlock: Identifiable, Equatable {
    var id: String { title }
    let title: String
    /// One line explaining how to run the block (format, rest, effort).
    let format: String?
    let items: [String]

    init(_ title: String, format: String? = nil, _ items: [String]) {
        self.title = title
        self.format = format
        self.items = items
    }
}

struct Workout: Identifiable, Equatable {
    /// yyyy-MM-dd, also the persistence key for completion.
    let id: String
    let date: Date
    let weekNumber: Int
    let phase: Phase
    let isDeload: Bool
    let kind: SessionKind
    let title: String
    let summary: String
    let minutes: Int
    /// Rate of perceived exertion, 1-10. Zero for rest.
    let rpe: Int
    let blocks: [WorkoutBlock]
    let coachNote: String?
}

struct PlanWeek: Identifiable, Equatable {
    var id: Int { number }
    let number: Int
    let phase: Phase
    let isDeload: Bool
    let start: Date
    let days: [Workout]

    var sessions: Int { days.filter { $0.kind.isTraining }.count }
    var minutes: Int { days.reduce(0) { $0 + $1.minutes } }
}

// MARK: - Logging

struct LogEntry: Codable, Equatable {
    var completedAt: Date
    var feltRPE: Int?
    var notes: String = ""
    var checked: [String] = []
    var done: Bool = false
}

struct Benchmark: Codable, Identifiable, Equatable {
    var id = UUID()
    var test: String
    var date: Date
    var seconds: Int
}

// MARK: - Calendar helpers

enum Cal {
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()

    static func day(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Monday on or before the date.
    static func monday(_ date: Date) -> Date {
        let d = day(date)
        let weekday = calendar.component(.weekday, from: d) // 1 = Sunday
        let back = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -back, to: d) ?? d
    }

    static func add(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func days(from: Date, to: Date) -> Int {
        calendar.dateComponents([.day], from: day(from), to: day(to)).day ?? 0
    }
}
