import Foundation

/// Official race loads for a division (2026/27 season). Sled weights include the sled.
struct RaceSpec {
    let sledPush: Double
    let sledPull: Double
    let farmers: Double      // per hand
    let sandbag: Double
    let wallBall: Double
    let wallBallTarget: String

    static func of(_ d: Division) -> RaceSpec {
        switch d {
        case .openWomen, .doublesWomen:
            return RaceSpec(sledPush: 102, sledPull: 78, farmers: 16, sandbag: 10, wallBall: 4, wallBallTarget: "2.70 m (about 9 ft)")
        case .openMen, .doublesMen:
            return RaceSpec(sledPush: 152, sledPull: 103, farmers: 24, sandbag: 20, wallBall: 6, wallBallTarget: "3.00 m (about 10 ft)")
        case .proWomen:
            return RaceSpec(sledPush: 152, sledPull: 103, farmers: 24, sandbag: 20, wallBall: 6, wallBallTarget: "2.70 m (about 9 ft)")
        case .proMen:
            return RaceSpec(sledPush: 202, sledPull: 153, farmers: 32, sandbag: 30, wallBall: 9, wallBallTarget: "3.00 m (about 10 ft)")
        case .doublesMixed:
            return RaceSpec(sledPush: 152, sledPull: 103, farmers: 24, sandbag: 20, wallBall: 6, wallBallTarget: "2.70 m women, 3.00 m men")
        }
    }
}

struct Station: Identifiable {
    let id: Int
    let name: String
    let symbol: String
    let distance: String
    let cues: [String]
    let pacing: String
    let mistakes: String
    let rule: String
    let noKit: String

    func load(_ s: RaceSpec) -> String {
        switch id {
        case 2: return Fmt.kg(s.sledPush)
        case 3: return Fmt.kg(s.sledPull)
        case 6: return "2 x \(Fmt.kg(s.farmers))"
        case 7: return Fmt.kg(s.sandbag)
        case 8: return "\(Fmt.kg(s.wallBall)) to \(s.wallBallTarget)"
        default: return "Bodyweight"
        }
    }

    static let all: [Station] = [
        Station(
            id: 1, name: "SkiErg", symbol: "figure.skiing.crosscountry", distance: "1000 m",
            cues: [
                "Hinge at the hips and drop your bodyweight onto the handles; arms finish the stroke, they do not start it.",
                "Reach tall, then drive down with lats and trunk. Hands finish beside the thighs.",
                "Hold a steady stroke rate and breathe out on every pull."
            ],
            pacing: "Settle 3-5 seconds per 500 m slower than your fresh 1 km pace. This is station one; the race is not won here.",
            mistakes: "Arm-only pulling and sprinting the first 250 m. Both spike the heart rate before the sleds.",
            rule: "Damper starts at 6 and you may change it. Feet stay on the platform.",
            noKit: "Rower for the same distance, or 40 band pull-downs plus 20 ball slams per 250 m."
        ),
        Station(
            id: 2, name: "Sled Push", symbol: "arrow.right.to.line", distance: "50 m (4 x 12.5 m)",
            cues: [
                "Arms long or locked, hips low, body at about 45 degrees.",
                "Short, quick steps on the balls of your feet. Never let the sled stop inside a lane.",
                "Rest only at the lane ends, 5-10 seconds, then go again."
            ],
            pacing: "Even lanes. Legs feel heavy on the next run for about 300 m, then recover. Expect it and do not panic.",
            mistakes: "Standing too upright, and long strides that stall the sled. Restarting a dead sled costs more than a slower steady push.",
            rule: "The whole sled must cross the line each lane. Race carpet is slower than most gym turf, so train heavier than race weight.",
            noKit: "Treadmill switched off, pushing the belt with hands on the rails, 4 x 30 seconds. Or a plate pushed on a towel across turf."
        ),
        Station(
            id: 3, name: "Sled Pull", symbol: "arrow.left.to.line", distance: "50 m (4 x 12.5 m)",
            cues: [
                "Sit back into a quarter squat and pull hand over hand, or lock the arms and walk backward inside the box.",
                "Use your legs and bodyweight. Arms alone will blow up your grip before the farmers carry.",
                "Keep the rope clear of your feet as it piles up."
            ],
            pacing: "Smooth and continuous. Many athletes lose the most time here, so it rewards practice more than any other station.",
            mistakes: "Pulling with bent arms only, and stepping out of the box.",
            rule: "Stay inside the athlete box and do not step on the solid front line. Standing only, no sitting.",
            noKit: "Heavy seated cable rows 4 x 15, plus backward sled or band-resisted walks. A rope looped round a rack with plates also works."
        ),
        Station(
            id: 4, name: "Burpee Broad Jumps", symbol: "figure.jumprope", distance: "80 m",
            cues: [
                "Step down, step up, jump. Stepping saves far more energy than it costs in time.",
                "Jump a repeatable distance, about 1.2-1.5 m, not your maximum.",
                "Find a rhythm and breathe: out as you go down, in as you stand."
            ],
            pacing: "Metronome effort. This is the highest heart-rate station for most people; start slower than feels necessary.",
            mistakes: "Max-distance jumps early, then long pauses on the floor.",
            rule: "Chest touches the floor. Take off and land with both feet together. No steps between the burpee and the jump.",
            noKit: "No kit needed. Mark 20 m and do 4 lengths."
        ),
        Station(
            id: 5, name: "Rowing", symbol: "figure.rower", distance: "1000 m",
            cues: [
                "Legs, then body, then arms. Reverse it on the way back.",
                "Long strokes at 24-28 per minute beat short frantic ones.",
                "Relax your grip. Your forearms are needed for the next station."
            ],
            pacing: "Treat it as active recovery at a strong aerobic effort, 5-8 seconds per 500 m off your fresh 1 km pace.",
            mistakes: "Racing the monitor. A 10 second gain here can cost a minute on the lunges.",
            rule: "Damper starts at 6 and you may change it. Stay seated until the monitor reads 1000 m.",
            noKit: "SkiErg for the same distance, or 1.2 km easy on a bike erg."
        ),
        Station(
            id: 6, name: "Farmers Carry", symbol: "figure.walk", distance: "200 m",
            cues: [
                "Stand tall, shoulders packed down, handles deep in the palm.",
                "Fast short steps. Walk quickly rather than shuffle-run if the bells swing.",
                "Chalk up before you lift."
            ],
            pacing: "Aim for unbroken. If you must stop, make it one planned 5 second break at halfway.",
            mistakes: "Starting at a jog and losing grip at 120 m.",
            rule: "Carry both kettlebells the whole way. Train to go unbroken so the rule never matters.",
            noKit: "Dumbbells or a trap bar at matching weight."
        ),
        Station(
            id: 7, name: "Sandbag Lunges", symbol: "figure.strengthtraining.traditional", distance: "100 m",
            cues: [
                "Bag high across the shoulders, chest up, eyes forward.",
                "Back knee kisses the floor every step, then stand fully.",
                "Keep moving. Slow continuous steps beat fast sets with stops."
            ],
            pacing: "Count steps in blocks of 20. Your quads decide the final run, so stay just under the burn.",
            mistakes: "Short steps that add reps, and dropping the bag.",
            rule: "Trailing knee touches the floor each rep. The bag stays on your shoulders; dropping it costs a time penalty.",
            noKit: "A barbell, a kettlebell in the front rack, or a weighted vest at matching weight."
        ),
        Station(
            id: 8, name: "Wall Balls", symbol: "circle.circle", distance: "100 reps",
            cues: [
                "Catch high, ride the ball down into the squat, and throw with your legs.",
                "Stand an arm's length from the wall and keep your elbows under the ball.",
                "Breathe out on every throw."
            ],
            pacing: "Have a plan before you arrive: for example 25-25-20-15-15 with 5 breaths between sets. Break before you fail.",
            mistakes: "Going to failure in set one, and shallow squats that get no-repped.",
            rule: "Hip crease below the knee and the ball must hit the target. No-reps do not count, and you cannot leave until 100 are done.",
            noKit: "Dumbbell or kettlebell thrusters, same reps, with a light load."
        )
    ]
}

struct RaceFact: Identifiable {
    var id: String { title }
    let title: String
    let body: String

    static let all: [RaceFact] = [
        RaceFact(title: "The format", body: "Eight rounds of a 1 km run followed by one station, always in the same order. Total: 8 km of running and 8 stations, every race, every city."),
        RaceFact(title: "The Roxzone", body: "The transition area between the run course and the stations. The clock keeps running. Mid-pack athletes spend 7-8 minutes here; walking with purpose and knowing the layout is free time."),
        RaceFact(title: "Penalties", body: "Stations 1-7 give one warning, then 15 seconds per further fault. Leaving any station unfinished is a disqualification this season. Count your own run laps: a missed lap carries a time penalty."),
        RaceFact(title: "Where the time goes", body: "Running is about half of a typical finish time. A median Open finisher is around 1:27 (men) and 1:36 (women), with wall balls, burpee broad jumps and sandbag lunges the longest stations."),
        RaceFact(title: "The fitness test (PFT)", body: "For time: 1000 m run, 50 burpee broad jumps, 100 bodyweight lunges, 1000 m row, 30 hand-release push-ups, 100 wall balls. Under 25 min suggests Open or Pro, 25-35 min Open, 30-40 min Doubles."),
        RaceFact(title: "Check before race day", body: "Rules change each season. Read the current athlete guide for your event, especially wall ball target height, burpee hand placement and whether kettlebells may be set down.")
    ]
}

/// Median race splits used to turn a target finish time into a pacing card.
enum RaceSplits {
    /// Share of total finish time: 8 runs combined, then stations 1...8, then roxzone.
    private static let men: [Double] = [41.8, 4.57, 3.05, 4.97, 5.63, 4.88, 2.18, 5.33, 7.05, 7.4]
    private static let women: [Double] = [46.7, 5.27, 2.9, 5.78, 6.75, 5.52, 2.3, 5.22, 6.7, 7.95]

    struct Card {
        let runPerKm: Int
        let stations: [Int]
        let roxzone: Int
    }

    static func card(target seconds: Int, division: Division) -> Card {
        let isWomen = division == .openWomen || division == .proWomen || division == .doublesWomen
        let base = isWomen ? women : men
        let total = base.reduce(0, +)
        let scale = Double(seconds) / total
        return Card(
            runPerKm: Int((base[0] * scale / 8).rounded()),
            stations: base[1...8].map { Int(($0 * scale).rounded()) },
            roxzone: Int((base[9] * scale).rounded())
        )
    }
}
