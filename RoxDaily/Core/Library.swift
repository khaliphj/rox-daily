import Foundation

/// Stand-alone "for time" sessions, shown as run / station pairs.
struct BonusWorkout: Identifiable {
    struct Row: Identifiable {
        let id: Int
        let run: String
        let amount: String
        let move: String
    }

    let id: String
    let name: String
    let tagline: String
    let capMinutes: Int
    let kit: String
    let rows: [Row]

    private static func make(_ name: String, _ tagline: String, cap: Int, kit: String, run: String, _ pairs: [(String, String)]) -> BonusWorkout {
        BonusWorkout(id: name, name: name, tagline: tagline, capMinutes: cap, kit: kit,
                     rows: pairs.enumerated().map { Row(id: $0.offset, run: run, amount: $0.element.0, move: $0.element.1) })
    }

    static let all: [BonusWorkout] = [
        make("Quarter Race", "Every station at a quarter of race distance", cap: 40, kit: "Full gym", run: "500 m", [
            ("250 m", "SkiErg"), ("12.5 m", "Sled push"), ("12.5 m", "Sled pull"), ("20 m", "Burpee broad jumps"),
            ("250 m", "Row"), ("50 m", "Farmers carry"), ("25 m", "Sandbag lunges"), ("25", "Wall balls")
        ]),
        make("No Kit Thirty", "Hotel, park or living room", cap: 35, kit: "Bodyweight", run: "400 m", [
            ("30", "Air squats"), ("30", "Push-ups"), ("30", "Alternating lunges"), ("30", "Sit-ups"),
            ("30", "Burpees"), ("30", "Mountain climbers")
        ]),
        make("Wall Ball Ladder", "Descending sets, runs stay the same", cap: 35, kit: "Wall ball", run: "600 m", [
            ("30", "Wall balls"), ("25", "Wall balls"), ("20", "Wall balls"), ("15", "Wall balls"), ("10", "Wall balls")
        ]),
        make("Engine Room", "Ergs and runs, nothing else", cap: 40, kit: "SkiErg + rower", run: "500 m", [
            ("500 m", "SkiErg"), ("500 m", "Row"), ("500 m", "SkiErg"), ("500 m", "Row"), ("500 m", "SkiErg"), ("500 m", "Row")
        ]),
        make("Grip Tax", "Hands and forearms under fatigue", cap: 35, kit: "Kettlebells", run: "300 m", [
            ("100 m", "Farmers carry"), ("25", "Kettlebell swings"), ("40 s", "Dead hang"),
            ("100 m", "Farmers carry"), ("25", "Kettlebell swings"), ("40 s", "Dead hang")
        ]),
        make("Leg Toll", "Quads first, then run on them", cap: 50, kit: "Sandbag, box, kettlebell", run: "800 m", [
            ("40 m", "Sandbag lunges"), ("30", "Goblet squats"), ("30", "Box step-ups"), ("40", "Wall balls"), ("40 m", "Sandbag lunges")
        ])
    ]
}
